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
  # Shared secrets / variables applied to every repo
  # ---------------------------------------------------------------------------
  shared_secrets = {
    "GH_TOKEN" = var.github_token
  }

  shared_variables = {
    "ENVIRONMENT" = "testing"
  }

  # ---------------------------------------------------------------------------
  # Repositories — add your repos here, only specify fields to override
  # ---------------------------------------------------------------------------
  repositories = {
    "github-creator" = {
      description                  = "Automated GitHub repository creation with branch protection, conventional commits, and Actions secrets/variables"
      visibility                   = "public"
      default_branch               = "master"
      topics                       = ["github", "terraform", "automation", "devops"]
      required_status_checks       = []    # enable after first workflow run
      enable_branch_naming_ruleset = false  # requires GitHub Enterprise Cloud (metadata ruleset)
    }
    "fitness-tracker" = {
      description                  = "little tool for tracking running/swim/cycling data and creating workouts"
      visibility                   = "public"
      default_branch               = "master"
      topics                       = ["github", "terraform", "automation", "devops", "sport"]
      required_status_checks       = []    # enable after first workflow run
      enable_branch_naming_ruleset = false  # requires GitHub Enterprise Cloud (metadata ruleset)
      required_reviewers           = 0     # solo project — no approval needed
      enforce_admins               = false # allow owner to merge without approval
    }
      "ollama-forge" = {
      description                  = "little tool for tracking running/swim/cycling data and creating workouts"
      visibility                   = "public"
      default_branch               = "master"
      topics                       = ["github", "terraform", "automation", "devops", "sport"]
      required_status_checks       = []    # enable after first workflow run
      enable_branch_naming_ruleset = false  # requires GitHub Enterprise Cloud (metadata ruleset)
      required_reviewers           = 0     # solo project — no approval needed
      enforce_admins               = false # allow owner to merge without approval
    }
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
    actions_secrets              = merge(local.shared_secrets, local.defaults.actions_secrets, lookup(repo, "actions_secrets", {}))
    actions_variables            = merge(local.shared_variables, local.defaults.actions_variables, lookup(repo, "actions_variables", {}))
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
