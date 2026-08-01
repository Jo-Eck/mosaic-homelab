terraform {
  required_version = ">= 1.10.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.66.0"
    }
    sops = {
      source  = "carlpett/sops"
      version = ">= 1.1.1"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 3.4.0"
    }
  }
}

# Reuse the proxmox module's encrypted API token (same infra age key on the
# runner) rather than duplicating the secret.
data "sops_file" "secrets" {
  source_file = "${path.module}/../proxmox/secrets.sops.yaml"
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = data.sops_file.secrets.data["proxmox_api_token"]
  insecure  = var.proxmox_insecure
}
