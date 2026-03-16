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
    required_status_checks       = ["check-commits"]
    branch_name_pattern          = "^(main|develop|feature/[a-z0-9._-]+|bugfix/[a-z0-9._-]+|hotfix/[a-z0-9._-]+|release/[0-9]+\\.[0-9]+\\.[0-9]+)$"
    enable_conventional_commits  = true
    enable_branch_naming_ruleset = true
    admin_bypass                 = false
    topics                       = []
    labels                       = {}
    actions_secrets              = {}
    actions_variables            = {}
  }

  # ---------------------------------------------------------------------------
  # Labels — fundamental set for open source projects
  # ---------------------------------------------------------------------------
  default_labels = {
    # Type
    "bug"           = { color = "d73a4a", description = "Something isn't working" }
    "feature"       = { color = "a2eeef", description = "New feature request" }
    "enhancement"   = { color = "84b6eb", description = "Improvement to existing functionality" }
    "documentation" = { color = "0075ca", description = "Improvements or additions to documentation" }
    "question"      = { color = "d876e3", description = "Further information is requested" }

    # Contributor onboarding (GitHub surfaces these on /contribute)
    "good first issue" = { color = "7057ff", description = "Good for newcomers" }
    "help wanted"      = { color = "008672", description = "Extra attention is needed" }

    # Priority
    "priority: critical" = { color = "b60205", description = "Must be fixed ASAP" }
    "priority: high"     = { color = "d93f0b", description = "High priority" }
    "priority: medium"   = { color = "fbca04", description = "Medium priority" }
    "priority: low"      = { color = "0e8a16", description = "Low priority — nice to have" }

    # Workflow / triage
    "needs triage" = { color = "ededed", description = "Needs initial review and categorization" }
    "wontfix"      = { color = "ffffff", description = "This will not be worked on" }
    "duplicate"    = { color = "cfd3d7", description = "This issue or pull request already exists" }
    "invalid"      = { color = "e4e669", description = "This doesn't seem right" }
    "stale"        = { color = "c2e0c6", description = "No recent activity" }

    # Area
    "ci/cd"           = { color = "f9d0c4", description = "Related to CI/CD pipelines" }
    "dependencies"    = { color = "0366d6", description = "Dependency updates" }
    "security"        = { color = "ee0701", description = "Security related issue" }
    "performance"     = { color = "ff7619", description = "Performance improvement" }
    "breaking change" = { color = "b60205", description = "Introduces a breaking change" }

    # PR workflow
    "needs review"      = { color = "fbca04", description = "PR is ready and waiting for review" }
    "changes requested" = { color = "e11d48", description = "Reviewer requested changes" }
    "approved"          = { color = "0e8a16", description = "PR has been approved" }
    "do not merge"      = { color = "b60205", description = "PR should not be merged yet" }
    "work in progress"  = { color = "f9d0c4", description = "PR is still being worked on" }
    "needs rebase"      = { color = "d93f0b", description = "PR has merge conflicts or needs rebase" }

    # PR size (useful for reviewers to estimate effort)
    "size: xs" = { color = "69db7c", description = "Tiny change — fewer than 10 lines" }
    "size: s"  = { color = "a2eeef", description = "Small change — fewer than 50 lines" }
    "size: m"  = { color = "fbca04", description = "Medium change — fewer than 200 lines" }
    "size: l"  = { color = "d93f0b", description = "Large change — fewer than 500 lines" }
    "size: xl" = { color = "b60205", description = "Very large change — 500+ lines, consider splitting" }
  }

  # ---------------------------------------------------------------------------
  # Shared secrets / variables applied to every repo
  # ---------------------------------------------------------------------------
  shared_secrets = {
    "GH_TOKEN" = var.github_token
  }

  shared_variables = {
    "ENVIRONMENT"            = "testing"
    "AWS_REGION"             = "eu-west-2"
    "TF_VARS_APPLY_ROLE_ARN" = var.tf_vars_apply_role_arn
    "TF_VARS_PLAN_ROLE_ARN"  = var.tf_vars_plan_role_arn
    "TF_WORKING_DIR"         = "terraform"
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
      enable_branch_naming_ruleset = false # requires GitHub Enterprise Cloud (metadata ruleset)
      admin_bypass                 = true  # allow admin to merge without approval
    }
    "fitness-tracker" = {
      description                  = "little tool for tracking running/swim/cycling data and creating workouts"
      visibility                   = "public"
      default_branch               = "master"
      topics                       = ["github", "terraform", "automation", "devops", "sport"]
      required_status_checks       = []    # enable after first workflow run
      enable_branch_naming_ruleset = false # requires GitHub Enterprise Cloud (metadata ruleset)
      required_reviewers           = 0     # solo project — no approval needed
      admin_bypass                 = true  # allow admin to merge without approval
    }
    "ollama-forge" = {
      description                  = "little tool to build an ai assistant based on ollama with rag and finetuning option on AWS"
      visibility                   = "public"
      default_branch               = "master"
      topics                       = ["github", "terraform", "automation", "devops", "sport"]
      required_status_checks       = []    # enable after first workflow run
      enable_branch_naming_ruleset = false # requires GitHub Enterprise Cloud (metadata ruleset)
      required_reviewers           = 0     # solo project — no approval needed
      admin_bypass                 = true  # allow admin to merge without approval
    }
    "trip-planner" = {
      description                  = "little tool for planning car trips"
      visibility                   = "public"
      default_branch               = "master"
      topics                       = ["github", "terraform", "automation", "devops", "sport", "travelling"]
      required_status_checks       = []    # enable after first workflow run
      enable_branch_naming_ruleset = false # requires GitHub Enterprise Cloud (metadata ruleset)
      required_reviewers           = 0     # solo project — no approval needed
      admin_bypass                 = true  # allow admin to merge without approval
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
    required_status_checks       = lookup(repo, "required_status_checks", local.defaults.required_status_checks)
    branch_name_pattern          = lookup(repo, "branch_name_pattern", local.defaults.branch_name_pattern)
    enable_conventional_commits  = lookup(repo, "enable_conventional_commits", local.defaults.enable_conventional_commits)
    enable_branch_naming_ruleset = lookup(repo, "enable_branch_naming_ruleset", local.defaults.enable_branch_naming_ruleset)
    admin_bypass                 = lookup(repo, "admin_bypass", local.defaults.admin_bypass)
    topics                       = lookup(repo, "topics", local.defaults.topics)
    labels                       = merge(local.default_labels, lookup(repo, "labels", local.defaults.labels))
    actions_secrets              = merge(local.shared_secrets, local.defaults.actions_secrets, lookup(repo, "actions_secrets", {}))
    actions_variables            = merge(local.shared_variables, local.defaults.actions_variables, lookup(repo, "actions_variables", {}))
  } }

  # Flatten labels: { "repo-name/label-name" => { repo, name, color, description } }
  repo_labels = merge([
    for name, cfg in local.repos : {
      for lname, lval in cfg.labels : "${name}/${lname}" => {
        repo        = name
        name        = lname
        color       = lval.color
        description = lval.description
      }
    }
  ]...)

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
