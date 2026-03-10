# =============================================================================
# GitHub Repository Creator — Multi-Repo with Defaults & Per-Repo Overrides
#
# Usage:
#   export GITHUB_TOKEN="ghp_xxxxxxxxxxxx"
#   terraform init
#   terraform plan
#   terraform apply
#
# For org repos, set: github_owner = "your-org"
# =============================================================================

terraform {
  required_version = ">= 1.5"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Provider
# ---------------------------------------------------------------------------
provider "github" {
  token = var.github_token != "" ? var.github_token : null
  owner = var.github_owner != "" ? var.github_owner : null
}

# ---------------------------------------------------------------------------
# Repositories
# ---------------------------------------------------------------------------
resource "github_repository" "this" {
  for_each = local.repos

  name        = each.key
  description = each.value.description
  visibility  = each.value.visibility
  topics      = each.value.topics

  auto_init          = true
  gitignore_template = each.value.gitignore_template != "" ? each.value.gitignore_template : null
  license_template   = each.value.license_template != "" ? each.value.license_template : null

  has_issues      = true
  has_discussions = false
  has_projects    = true
  has_wiki        = false

  allow_merge_commit = !each.value.require_linear_history
  allow_squash_merge = true
  allow_rebase_merge = true
  allow_auto_merge   = true

  squash_merge_commit_title   = "PR_TITLE"
  squash_merge_commit_message = "PR_BODY"

  delete_branch_on_merge = true

  vulnerability_alerts = true

  lifecycle {
    prevent_destroy = false
  }
}

# ---------------------------------------------------------------------------
# Branch Protection
# ---------------------------------------------------------------------------
resource "github_branch_protection" "default" {
  for_each = local.repos

  repository_id = github_repository.this[each.key].node_id
  pattern       = each.value.default_branch

  enforce_admins          = each.value.enforce_admins
  require_signed_commits  = false
  required_linear_history = each.value.require_linear_history
  allows_deletions        = false
  allows_force_pushes     = false

  required_pull_request_reviews {
    required_approving_review_count = each.value.required_reviewers
    dismiss_stale_reviews           = each.value.dismiss_stale_reviews
    restrict_dismissals             = false
  }

  # Note: Status checks only work once the workflow has run at least once.
  dynamic "required_status_checks" {
    for_each = length(each.value.required_status_checks) > 0 ? [1] : []
    content {
      strict   = true
      contexts = each.value.required_status_checks
    }
  }

  # Workflow file must be committed before branch protection blocks direct pushes.
  # On first apply this ensures correct ordering. If branch protection already
  # exists you may need to: terraform destroy -target=github_branch_protection.default
  # then re-apply so the file is created first.
  depends_on = [github_repository_file.conventional_commits_workflow]
}

# ---------------------------------------------------------------------------
# Repository Rulesets — Branch Naming Convention
# ---------------------------------------------------------------------------
resource "github_repository_ruleset" "branch_naming" {
  for_each = { for k, v in local.repos : k => v if v.enable_branch_naming_ruleset }

  name        = "branch-naming-convention"
  repository  = github_repository.this[each.key].name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~ALL"]
      exclude = []
    }
  }

  rules {
    branch_name_pattern {
      negate   = false
      operator = "regex"
      pattern  = each.value.branch_name_pattern
    }
  }
}

# ---------------------------------------------------------------------------
# Conventional Commits — GitHub Actions Workflow
# ---------------------------------------------------------------------------
resource "github_repository_file" "conventional_commits_workflow" {
  for_each = { for k, v in local.repos : k => v if v.enable_conventional_commits }

  repository          = github_repository.this[each.key].name
  branch              = each.value.default_branch
  file                = ".github/workflows/conventional-commits.yml"
  commit_message      = "ci: add conventional commits validation workflow"
  overwrite_on_create = true

  content = <<-YAML
    name: Conventional Commits Check

    on:
      pull_request:
        types: [opened, synchronize, reopened, edited]

    permissions:
      pull_requests: read
      statuses: write

    jobs:
      check-commits:
        name: Validate Conventional Commits
        runs-on: ubuntu-latest
        steps:
          - uses: actions/checkout@v4
            with:
              fetch-depth: 0

          - name: Check commit messages
            run: |
              PATTERN='^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(.+\))?!?:\s.+'
              FAILED=0
              while IFS= read -r sha; do
                MSG=$$(git log --format='%s' -n1 "$$sha")
                if ! echo "$$MSG" | grep -qE "$$PATTERN"; then
                  echo "Non-conventional commit: $$MSG ($$sha)"
                  FAILED=1
                fi
              done < <(git log --format='%H' origin/$${{ github.base_ref }}..$${{ github.event.pull_request.head.sha }})

              if [ "$$FAILED" -eq 1 ]; then
                echo ""
                echo "Commits must follow Conventional Commits: https://www.conventionalcommits.org"
                echo "Format: <type>(<optional scope>): <description>"
                echo "Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert"
                exit 1
              fi
              echo "All commits follow Conventional Commits"
  YAML
}

# ---------------------------------------------------------------------------
# Actions Secrets
# ---------------------------------------------------------------------------
resource "github_actions_secret" "this" {
  for_each = local.repo_secrets

  repository      = github_repository.this[each.value.repo].name
  secret_name     = each.value.key
  plaintext_value = each.value.value
}

# ---------------------------------------------------------------------------
# Actions Variables
# ---------------------------------------------------------------------------
resource "github_actions_variable" "this" {
  for_each = local.repo_variables

  repository    = github_repository.this[each.value.repo].name
  variable_name = each.value.key
  value         = each.value.value
}
