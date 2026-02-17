# ---------------------------------------------------------------------------
# Defaults — shared settings applied to every repo unless overridden
# ---------------------------------------------------------------------------
locals {
  defaults = {
    visibility                   = "private"
    default_branch               = "main"
    gitignore_template           = ""
    license_template             = "mit"
    required_reviewers           = 1
    dismiss_stale_reviews        = true
    require_linear_history       = true
    enforce_admins               = true
    required_status_checks       = ["check-commits"]
    branch_name_pattern          = "^(main|develop|feature/[a-z0-9._-]+|bugfix/[a-z0-9._-]+|hotfix/[a-z0-9._-]+|release/[0-9]+\\.[0-9]+\\.[0-9]+)$"
    enable_conventional_commits  = true
    enable_branch_naming_ruleset = true
    topics                       = []
    actions_secrets              = {}
    actions_variables            = {}
  }

  # ---------------------------------------------------------------------------
  # Repositories — add your repos here, only specify fields to override
  # ---------------------------------------------------------------------------
  repositories = {
    # Example: uses all defaults, just set description and gitignore
    # "my-api" = {
    #   description        = "REST API service"
    #   gitignore_template = "Python"
    #   topics             = ["api", "python"]
    # }
    #
    # Example: override visibility and reviewers
    # "my-frontend" = {
    #   description        = "React frontend"
    #   visibility         = "public"
    #   gitignore_template = "Node"
    #   required_reviewers = 2
    # }
    #
    # Example: repo with its own secrets and variables
    # "my-infra" = {
    #   description        = "Terraform infrastructure"
    #   gitignore_template = "Terraform"
    #   actions_secrets = {
    #     AWS_ACCESS_KEY_ID     = "AKIA..."
    #     AWS_SECRET_ACCESS_KEY = "wJalr..."
    #   }
    #   actions_variables = {
    #     TF_VARS_PLAN_ROLE_ARN = "arn:aws:iam::123456789012:role/plan-role"
    #   }
    # }
    #
    # Example: disable features for a lightweight repo
    # "my-experiment" = {
    #   description                  = "Quick experiment"
    #   enable_conventional_commits  = false
    #   enable_branch_naming_ruleset = false
    #   enforce_admins               = false
    #   required_status_checks       = []
    # }
  }
}

# ---------------------------------------------------------------------------
# Merge defaults with per-repo overrides
# ---------------------------------------------------------------------------
locals {
  repos = { for name, repo in local.repositories : name => {
    description                  = lookup(repo, "description", "")
    visibility                   = lookup(repo, "visibility", local.defaults.visibility)
    default_branch               = lookup(repo, "default_branch", local.defaults.default_branch)
    gitignore_template           = lookup(repo, "gitignore_template", local.defaults.gitignore_template)
    license_template             = lookup(repo, "license_template", local.defaults.license_template)
    required_reviewers           = lookup(repo, "required_reviewers", local.defaults.required_reviewers)
    dismiss_stale_reviews        = lookup(repo, "dismiss_stale_reviews", local.defaults.dismiss_stale_reviews)
    require_linear_history       = lookup(repo, "require_linear_history", local.defaults.require_linear_history)
    enforce_admins               = lookup(repo, "enforce_admins", local.defaults.enforce_admins)
    required_status_checks       = lookup(repo, "required_status_checks", local.defaults.required_status_checks)
    branch_name_pattern          = lookup(repo, "branch_name_pattern", local.defaults.branch_name_pattern)
    enable_conventional_commits  = lookup(repo, "enable_conventional_commits", local.defaults.enable_conventional_commits)
    enable_branch_naming_ruleset = lookup(repo, "enable_branch_naming_ruleset", local.defaults.enable_branch_naming_ruleset)
    topics                       = lookup(repo, "topics", local.defaults.topics)
    actions_secrets              = merge(local.defaults.actions_secrets, lookup(repo, "actions_secrets", {}))
    actions_variables            = merge(local.defaults.actions_variables, lookup(repo, "actions_variables", {}))
  } }

  # Flatten secrets: { "repo-name/SECRET_NAME" => { repo, key, value } }
  repo_secrets = merge([
    for name, cfg in local.repos : {
      for sk, sv in cfg.actions_secrets : "${name}/${sk}" => {
        repo  = name
        key   = sk
        value = sv
      }
    }
  ]...)

  # Flatten variables: { "repo-name/VAR_NAME" => { repo, key, value } }
  repo_variables = merge([
    for name, cfg in local.repos : {
      for vk, vv in cfg.actions_variables : "${name}/${vk}" => {
        repo  = name
        key   = vk
        value = vv
      }
    }
  ]...)
}
