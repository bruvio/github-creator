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
