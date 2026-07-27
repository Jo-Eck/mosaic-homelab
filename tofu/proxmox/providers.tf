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
  }
}

# Proxmox API credentials, decrypted from SOPS at plan/apply time using the
# `infra` age key that lives on the Pi runner (never in this repo as plaintext).
data "sops_file" "secrets" {
  source_file = "${path.module}/secrets.sops.yaml"
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = data.sops_file.secrets.data["proxmox_api_token"]
  insecure  = var.proxmox_insecure

  # No SSH block: this module only creates VMs and downloads the Talos ISO, which
  # bpg does entirely over the Proxmox API. So the runner never SSHes into the
  # hosts and root SSH can stay disabled. If you later add resources that need
  # SSH (e.g. cloud-init snippet uploads), add an ssh { } block with a non-root
  # user that has scoped NOPASSWD sudo.
}
