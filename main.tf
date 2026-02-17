# =============================================================================
# GitHub Repository with Branch Protection, Rulesets & Conventional Commits
#
# Usage:
#   export GITHUB_TOKEN="ghp_xxxxxxxxxxxx"
#   terraform init
#   terraform plan
#   terraform apply
#
# For org repos, set: var.github_owner = "your-org"
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
# Variables
# ---------------------------------------------------------------------------
variable "github_token" {
  description = "GitHub Personal Access Token"
  type        = string
  sensitive   = true
  default     = "" # Uses GITHUB_TOKEN env var if empty
}

variable "github_owner" {
  description = "GitHub owner (user or org). Leave empty for personal repos."
  type        = string
  default     = ""
}

variable "repo_name" {
  description = "Repository name"
  type        = string
}

variable "repo_description" {
  description = "Repository description"
  type        = string
  default     = ""
}

variable "visibility" {
  description = "Repository visibility: public or private"
  type        = string
  default     = "private"

  validation {
    condition     = contains(["public", "private"], var.visibility)
    error_message = "Visibility must be 'public' or 'private'."
  }
}

variable "default_branch" {
  description = "Default branch name"
  type        = string
  default     = "main"
}

variable "gitignore_template" {
  description = "Gitignore template (e.g. Python, Node, Go). Empty to skip."
  type        = string
  default     = ""
}

variable "license_template" {
  description = "License template (e.g. mit, apache-2.0, gpl-3.0). Empty to skip."
  type        = string
  default     = "mit"
}

variable "required_reviewers" {
  description = "Number of required PR review approvals"
  type        = number
  default     = 1
}

variable "dismiss_stale_reviews" {
  description = "Dismiss stale PR reviews when new commits are pushed"
  type        = bool
  default     = true
}

variable "require_linear_history" {
  description = "Require linear commit history (no merge commits)"
  type        = bool
  default     = true
}

variable "enforce_admins" {
  description = "Enforce branch protection for admins too"
  type        = bool
  default     = true
}

variable "required_status_checks" {
  description = "List of required status check contexts"
  type        = list(string)
  default     = ["check-commits"]
}

variable "branch_name_pattern" {
  description = "Regex pattern for allowed branch names (like GitLab push rules)"
  type        = string
  default     = "^(main|develop|feature/[a-z0-9._-]+|bugfix/[a-z0-9._-]+|hotfix/[a-z0-9._-]+|release/[0-9]+\\.[0-9]+\\.[0-9]+)$"
}

variable "enable_conventional_commits" {
  description = "Add GitHub Actions workflow to enforce conventional commits"
  type        = bool
  default     = true
}

variable "enable_branch_naming_ruleset" {
  description = "Enable branch naming convention via repository ruleset"
  type        = bool
  default     = true
}

variable "topics" {
  description = "Repository topics/tags"
  type        = list(string)
  default     = []
}

variable "actions_secrets" {
  description = "Map of GitHub Actions secrets to create. Values are plaintext and stored encrypted by GitHub."
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "actions_variables" {
  description = "Map of GitHub Actions variables to create."
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Provider
# ---------------------------------------------------------------------------
provider "github" {
  token = var.github_token != "" ? var.github_token : null
  owner = var.github_owner != "" ? var.github_owner : null
}

# ---------------------------------------------------------------------------
# Repository
# ---------------------------------------------------------------------------
resource "github_repository" "this" {
  name        = var.repo_name
  description = var.repo_description
  visibility  = var.visibility
  topics      = var.topics

  auto_init          = true
  gitignore_template = var.gitignore_template != "" ? var.gitignore_template : null
  license_template   = var.license_template != "" ? var.license_template : null

  has_issues      = true
  has_discussions = false
  has_projects    = true
  has_wiki        = false
  has_downloads   = false

  allow_merge_commit = !var.require_linear_history
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
  repository_id = github_repository.this.node_id
  pattern       = var.default_branch

  enforce_admins          = var.enforce_admins
  require_signed_commits  = false
  required_linear_history = var.require_linear_history
  allows_deletions        = false
  allows_force_pushes     = false

  required_pull_request_reviews {
    required_approving_review_count = var.required_reviewers
    dismiss_stale_reviews           = var.dismiss_stale_reviews
    restrict_dismissals             = false
  }

  # Note: Status checks only work once the workflow has run at least once.
  # You may need to apply this after the first PR triggers the workflow.
  dynamic "required_status_checks" {
    for_each = length(var.required_status_checks) > 0 ? [1] : []
    content {
      strict   = true
      contexts = var.required_status_checks
    }
  }
}

# ---------------------------------------------------------------------------
# Repository Ruleset — Branch Naming Convention (like GitLab push rules)
# ---------------------------------------------------------------------------
resource "github_repository_ruleset" "branch_naming" {
  count = var.enable_branch_naming_ruleset ? 1 : 0

  name        = "branch-naming-convention"
  repository  = github_repository.this.name
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
      name     = "branch naming convention"
      negate   = false
      operator = "regex"
      pattern  = var.branch_name_pattern
    }
  }
}

# ---------------------------------------------------------------------------
# Conventional Commits — GitHub Actions Workflow
# ---------------------------------------------------------------------------
resource "github_repository_file" "conventional_commits_workflow" {
  count = var.enable_conventional_commits ? 1 : 0

  repository          = github_repository.this.name
  branch              = var.default_branch
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
  for_each = var.actions_secrets

  repository      = github_repository.this.name
  secret_name     = each.key
  plaintext_value = each.value
}

# ---------------------------------------------------------------------------
# Actions Variables
# ---------------------------------------------------------------------------
resource "github_actions_variable" "this" {
  for_each = var.actions_variables

  repository    = github_repository.this.name
  variable_name = each.key
  value         = each.value
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------
output "repository_url" {
  description = "Repository HTTPS URL"
  value       = github_repository.this.html_url
}

output "repository_ssh_url" {
  description = "Repository SSH URL"
  value       = github_repository.this.ssh_clone_url
}

output "repository_full_name" {
  description = "Full repository name (owner/repo)"
  value       = github_repository.this.full_name
}

output "branch_protection" {
  description = "Branch protection summary"
  value = {
    branch             = var.default_branch
    required_reviewers = var.required_reviewers
    linear_history     = var.require_linear_history
    enforce_admins     = var.enforce_admins
    status_checks      = var.required_status_checks
  }
}

output "branch_naming_pattern" {
  description = "Branch naming regex pattern"
  value       = var.enable_branch_naming_ruleset ? var.branch_name_pattern : "disabled"
}

output "actions_secrets" {
  description = "List of GitHub Actions secrets created"
  value       = keys(var.actions_secrets)
}

output "actions_variables" {
  description = "GitHub Actions variables created"
  value       = { for k, v in var.actions_variables : k => v }
}
