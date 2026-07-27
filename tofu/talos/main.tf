# The Talos node topology is defined once, in the proxmox module. We read it
# back here so there's a single source of truth for names/roles/IPs.
data "terraform_remote_state" "proxmox" {
  backend = "s3"
  config = {
    bucket = "mosaic-tofu-state"
    key    = "proxmox/terraform.tfstate"
    region = "eu-central-003"

    endpoints = {
      s3 = "https://s3.eu-central-003.backblazeb2.com"
    }

    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }
}

locals {
  nodes              = data.terraform_remote_state.proxmox.outputs.talos_nodes
  cluster_name       = data.terraform_remote_state.proxmox.outputs.cluster_name
  talos_schematic_id = data.terraform_remote_state.proxmox.outputs.talos_schematic_id
  controlplanes      = { for k, v in local.nodes : k => v if v.role == "controlplane" }
  workers            = { for k, v in local.nodes : k => v if v.role == "worker" }

  # Single control-plane: its IP is the cluster endpoint.
  cp_ip            = one([for k, v in local.nodes : v.ip if v.role == "controlplane"])
  cluster_endpoint = "https://${local.cp_ip}:6443"

  # Per-node patch generated from the topology map (no duplicated IP lists).
  node_patches = {
    for name, n in local.nodes : name => yamlencode({
      machine = merge(
        {
          network = {
            nameservers = var.nameservers
            interfaces = [{
              deviceSelector = { physical = true }
              addresses      = ["${n.ip}/${var.network_cidr}"]
              routes         = [{ network = "0.0.0.0/0", gateway = var.network_gateway }]
            }]
          }
          install = {
            disk  = var.install_disk
            image = "factory.talos.dev/installer/${local.talos_schematic_id}:${var.talos_version}"
          }
        },
        n.role == "controlplane" ? { certSANs = [n.ip] } : {}
      )
    })
  }

  # Talos >= 1.12 configures the hostname via a dedicated HostnameConfig
  # document (default `auto: stable`). Setting the legacy
  # machine.network.hostname as well fails validation ("static hostname is
  # already set in v1alpha1 config"), so the static hostname is set here
  # instead. `auto: "off"` is required alongside a static hostname (they are
  # mutually exclusive unless auto is off).
  hostname_patches = {
    for name in keys(local.nodes) : name => yamlencode({
      apiVersion = "v1alpha1"
      kind       = "HostnameConfig"
      auto       = "off"
      hostname   = name
    })
  }
}
