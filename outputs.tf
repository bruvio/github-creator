# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------
output "repositories" {
  description = "Map of repo name to URLs and metadata"
  value = { for name, repo in github_repository.this : name => {
    url       = repo.html_url
    ssh_url   = repo.ssh_clone_url
    full_name = repo.full_name
  } }
}

output "branch_protection" {
  description = "Branch protection summary per repo"
  value = { for name, cfg in local.repos : name => {
    branch             = cfg.default_branch
    required_reviewers = cfg.required_reviewers
    linear_history     = cfg.require_linear_history
    enforce_admins     = cfg.enforce_admins
    status_checks      = cfg.required_status_checks
  } }
}

output "branch_naming_patterns" {
  description = "Branch naming regex per repo"
  value = { for name, cfg in local.repos : name =>
    cfg.enable_branch_naming_ruleset ? cfg.branch_name_pattern : "disabled"
  }
}

output "actions_secrets" {
  description = "Secret names created per repo"
  value       = { for name, cfg in local.repos : name => keys(cfg.actions_secrets) if length(cfg.actions_secrets) > 0 }
}

output "actions_variables" {
  description = "Variable names created per repo"
  value       = { for name, cfg in local.repos : name => keys(cfg.actions_variables) if length(cfg.actions_variables) > 0 }
}
