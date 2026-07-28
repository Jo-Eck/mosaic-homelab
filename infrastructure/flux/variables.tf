variable "github_owner" {
  description = "GitHub org/user that owns the GitOps repo."
  type        = string
  default     = "Jo-Eck"
}

variable "github_repository" {
  description = "GitOps repository name."
  type        = string
  default     = "MOSAIC"
}

variable "github_branch" {
  description = "Branch Flux reconciles from."
  type        = string
  default     = "main"
}

variable "github_token" {
  description = <<-EOT
    GitHub PAT allowed to add a deploy key to the repo. Supplied via
    TF_VAR_github_token (the FLUX_GITHUB_TOKEN Actions secret) — never committed.
  EOT
  type        = string
  sensitive   = true
}

variable "flux_path" {
  description = "Repo path Flux syncs (the cluster overlay holding the Kustomizations)."
  type        = string
  default     = "gitops/clusters/mosaic"
}

variable "flux_version" {
  description = "Flux version to install (keep in sync with .mise.toml flux2). 2.6.x supports k8s 1.32."
  type        = string
  default     = "v2.6.4"
}
