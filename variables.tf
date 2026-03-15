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

variable "tf_vars_apply_role_arn" {
  description = "IAM role ARN for Terraform apply in GitHub Actions"
  type        = string
  sensitive   = true
}

variable "tf_vars_plan_role_arn" {
  description = "IAM role ARN for Terraform plan in GitHub Actions"
  type        = string
  sensitive   = true
}
