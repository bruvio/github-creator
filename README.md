# GitHub Repository Creator

Automate GitHub repository creation with enterprise-grade rules — branch protection, conventional commits, branch naming enforcement, and Actions secrets/variables — all in one step.

Two approaches are available: a **Python script** for quick imperative usage, or **Terraform** for declarative, repeatable provisioning.

## What gets configured

| Feature | GitHub Mechanism | GitLab Equivalent |
|---------|-----------------|-------------------|
| Branch protection (required reviews, status checks) | Branch Protection Rules | Protected Branches |
| Conventional commits enforcement | GitHub Actions + required status check | Push Rules (commit message regex) |
| Branch naming regex | Repository Rulesets (`branch_name_pattern`) | Push Rules (branch name regex) |
| Linear history | Branch Protection (`required_linear_history`) | Merge settings |
| Auto-init (README, .gitignore, license) | Repo creation params | Project creation params |
| Actions secrets | `github_actions_secret` (Terraform) | CI/CD Variables (masked) |
| Actions variables | `github_actions_variable` (Terraform) | CI/CD Variables |

### Default branch naming pattern

```
^(main|develop|feature/[a-z0-9._-]+|bugfix/[a-z0-9._-]+|hotfix/[a-z0-9._-]+|release/[0-9]+\.[0-9]+\.[0-9]+)$
```

Allows: `main`, `develop`, `feature/add-auth`, `bugfix/fix-login`, `hotfix/patch-1.2`, `release/1.0.0`

### Conventional commits types

`feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`

---

## Prerequisites

- A **GitHub Personal Access Token** with `repo`, `workflow`, and `admin:org` (if using orgs) scopes
- **Python 3** + `requests` (for the Python approach)
- **Terraform >= 1.5** (for the Terraform approach)

```bash
export GITHUB_TOKEN="ghp_xxxxxxxxxxxx"
```

---

## Option 1: Terraform (recommended)

### Quick start

```bash
# 1. Copy the example tfvars
cp terraform.tfvars.example terraform.tfvars

# 2. Edit with your settings
vim terraform.tfvars

# 3. Init, plan, apply
terraform init
terraform plan
terraform apply
```

### Example `terraform.tfvars`

```hcl
repo_name        = "my-new-service"
repo_description = "Microservice created via Terraform"
visibility       = "private"
default_branch   = "main"

# Optional: set org for organisation repos
# github_owner = "my-org"

# Auto-init
license_template   = "mit"
gitignore_template = "Python"

# Topics
topics = ["microservice", "python", "platform"]

# Branch protection
required_reviewers     = 1
dismiss_stale_reviews  = true
require_linear_history = true
enforce_admins         = true
required_status_checks = ["check-commits"]

# Branch naming regex
branch_name_pattern = "^(main|develop|feature/[a-z0-9._-]+|bugfix/[a-z0-9._-]+|hotfix/[a-z0-9._-]+|release/[0-9]+\\.[0-9]+\\.[0-9]+)$"

# Feature toggles
enable_conventional_commits  = true
enable_branch_naming_ruleset = true

# GitHub Actions secrets (stored encrypted by GitHub)
actions_secrets = {
  AWS_ACCESS_KEY_ID     = "AKIA..."
  AWS_SECRET_ACCESS_KEY = "wJalr..."
}

# GitHub Actions variables (plaintext, visible in workflow logs)
actions_variables = {
  TF_VARS_PLAN_ROLE_ARN  = "arn:aws:iam::123456789012:role/plan-role"
  TF_VARS_APPLY_ROLE_ARN = "arn:aws:iam::123456789012:role/apply-role"
  AWS_REGION             = "eu-west-2"
}
```

### All Terraform variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `github_token` | `string` | `""` (uses `GITHUB_TOKEN` env var) | GitHub Personal Access Token |
| `github_owner` | `string` | `""` (personal account) | GitHub org name |
| `repo_name` | `string` | (required) | Repository name |
| `repo_description` | `string` | `""` | Repository description |
| `visibility` | `string` | `"private"` | `"public"` or `"private"` |
| `default_branch` | `string` | `"main"` | Default branch name |
| `gitignore_template` | `string` | `""` | Gitignore template (e.g. `Python`, `Node`, `Go`) |
| `license_template` | `string` | `"mit"` | License (e.g. `mit`, `apache-2.0`, `gpl-3.0`) |
| `required_reviewers` | `number` | `1` | Required PR approvals |
| `dismiss_stale_reviews` | `bool` | `true` | Dismiss stale reviews on new commits |
| `require_linear_history` | `bool` | `true` | No merge commits allowed |
| `enforce_admins` | `bool` | `true` | Enforce rules for admins too |
| `required_status_checks` | `list(string)` | `["check-commits"]` | Required CI status checks |
| `branch_name_pattern` | `string` | see above | Regex for allowed branch names |
| `enable_conventional_commits` | `bool` | `true` | Add conventional commits GH Actions workflow |
| `enable_branch_naming_ruleset` | `bool` | `true` | Enable branch naming ruleset |
| `topics` | `list(string)` | `[]` | Repository topics/tags |
| `actions_secrets` | `map(string)` | `{}` | GitHub Actions secrets (name -> value) |
| `actions_variables` | `map(string)` | `{}` | GitHub Actions variables (name -> value) |

### Outputs

| Output | Description |
|--------|-------------|
| `repository_url` | Repository HTTPS URL |
| `repository_ssh_url` | Repository SSH clone URL |
| `repository_full_name` | Full name (`owner/repo`) |
| `branch_protection` | Branch protection summary |
| `branch_naming_pattern` | Active branch naming regex or `"disabled"` |
| `actions_secrets` | List of secret names created |
| `actions_variables` | Map of variable names and values |

### Importing existing repos

```bash
terraform import github_repository.this my-existing-repo
```

### Notes

- **Status checks caveat**: The `check-commits` status check only becomes available after the conventional commits workflow has run at least once. On the very first apply, Terraform may warn about this. After the first PR triggers the workflow, re-apply to lock it in.
- **Rulesets require GitHub Pro/Team/Enterprise** for private repos. Public repos can use rulesets on any plan.
- **Secrets**: Values are sent as plaintext to Terraform but stored encrypted by GitHub. The Terraform state will contain the plaintext values, so protect your state file accordingly.

---

## Option 2: Python Script

For quick, one-off repo creation without Terraform state management.

### Quick start

```bash
pip install requests

# Minimal — creates private repo with all defaults
python github_repo_creator.py --name my-service

# Full options
python github_repo_creator.py \
  --name my-service \
  --org my-org \
  --description "Platform microservice" \
  --private \
  --license mit \
  --gitignore Python \
  --required-reviewers 2 \
  --branch-pattern '^(main|develop|feature/[a-z0-9._-]+)$'

# Skip optional features
python github_repo_creator.py \
  --name quick-repo \
  --skip-conventional-commits \
  --skip-branch-naming
```

### All flags

| Flag | Default | Description |
|------|---------|-------------|
| `--name` | (required) | Repo name |
| `--org` | personal | GitHub org |
| `--description` | `""` | Repo description |
| `--private` / `--public` | private | Visibility |
| `--license` | `mit` | License template |
| `--gitignore` | `""` | Gitignore template |
| `--default-branch` | `main` | Default branch |
| `--required-reviewers` | `1` | Required PR approvals |
| `--branch-pattern` | see above | Branch naming regex |
| `--status-checks` | `check-commits` | Required status checks |
| `--skip-conventional-commits` | false | Skip GH Action workflow |
| `--skip-branch-naming` | false | Skip branch naming ruleset |
| `--token` | `GITHUB_TOKEN` env var | GitHub PAT |

---

## CI/CD Pipeline

This repository includes a CI/CD pipeline (`.github/workflows/release.yml`) that runs on push/PR to `master`:

1. **Terraform Format Check** — validates `main.tf` formatting
2. **Ruff Lint** — lints and format-checks `github_repo_creator.py`
3. **Semantic Release** (merge to master only) — automatic versioning and changelog based on conventional commits

### Semantic release

Commits to `master` are automatically analysed and versioned:

| Commit prefix | Version bump |
|---------------|-------------|
| `fix:` | Patch (1.0.0 -> 1.0.1) |
| `feat:` | Minor (1.0.0 -> 1.1.0) |
| `feat!:` or `BREAKING CHANGE:` | Major (1.0.0 -> 2.0.0) |

### Pre-commit hooks

Install pre-commit hooks locally to enforce quality before push:

```bash
pip install pre-commit
pre-commit install
pre-commit install --hook-type commit-msg
```

Hooks configured: trailing whitespace, ruff (lint + format), terraform fmt, gitleaks (secret scanning), yamllint, conventional commits.

---

## Project Structure

```
.
├── main.tf                      # Terraform config (repo + protection + secrets + variables)
├── terraform.tfvars.example     # Example variable values
├── github_repo_creator.py       # Python script (alternative approach)
├── .releaserc.yml               # Semantic release configuration
├── .pre-commit-config.yaml      # Pre-commit hooks
├── .gitignore                   # Git ignore rules
├── .github/
│   └── workflows/
│       └── release.yml          # CI/CD pipeline
└── README.md
```
