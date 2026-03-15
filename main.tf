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

  name           = each.key
  description    = each.value.description
  visibility     = each.value.visibility
  topics         = each.value.topics
  default_branch = each.value.default_branch

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
# Branch Protection (Rulesets API — supports bypass actors on personal repos)
# ---------------------------------------------------------------------------
resource "github_repository_ruleset" "branch_protection" {
  for_each = local.repos

  name        = "branch-protection"
  repository  = github_repository.this[each.key].name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["refs/heads/${each.value.default_branch}"]
      exclude = []
    }
  }

  # Repository admin role can bypass — covers owner and CI using owner's PAT
  # (GitHub Actions bot can't be a bypass actor on personal repos)
  dynamic "bypass_actors" {
    for_each = each.value.admin_bypass ? [1] : []
    content {
      actor_id    = 5 # Repository Admin role
      actor_type  = "RepositoryRole"
      bypass_mode = "always"
    }
  }

  rules {
    # Require PRs with configurable reviewer count
    pull_request {
      required_approving_review_count   = each.value.required_reviewers
      dismiss_stale_reviews_on_push     = each.value.dismiss_stale_reviews
      require_last_push_approval        = false
      required_review_thread_resolution = false
    }

    # Enforce linear history (no merge commits)
    required_linear_history = each.value.require_linear_history

    # Block deletions and force pushes
    deletion         = true
    non_fast_forward = true

    # Status checks — only when configured
    dynamic "required_status_checks" {
      for_each = length(each.value.required_status_checks) > 0 ? [1] : []
      content {
        dynamic "required_check" {
          for_each = each.value.required_status_checks
          content {
            context = required_check.value
          }
        }
        strict_required_status_checks_policy = true
      }
    }
  }

  # Workflow file must be committed before rulesets block direct pushes.
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
      pull-requests: read
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
            shell: bash
            run: |
              PATTERN='^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(.+\))?!?:\s.+'
              FAILED=0
              while IFS= read -r sha; do
                # Skip merge commits
                if [ "$(git rev-list --parents -n1 "$sha" | wc -w)" -gt 2 ]; then
                  continue
                fi
                MSG=$(git log --format='%s' -n1 "$sha")
                if ! echo "$MSG" | grep -qE "$PATTERN"; then
                  echo "Non-conventional commit: $MSG ($sha)"
                  FAILED=1
                fi
              done < <(git log --format='%H' origin/$${{ github.base_ref }}..$${{ github.event.pull_request.head.sha }})

              if [ "$FAILED" -eq 1 ]; then
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
