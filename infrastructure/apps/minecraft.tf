# MeatballCraft LXC on Legion. Tofu creates the container; the `minecraft` Ansible
# role installs + configures the server. The world lives on the rootfs, so the
# lifecycle guards below stop a template/key change from recreating (wiping) it.

# Root SSH keys = the GitHub user's keys (manual runs) + the CI runner's deploy
# key. Sorted so upstream reordering isn't seen as drift.
data "http" "github_keys" {
  url = "https://github.com/${var.ssh_key_github_user}.keys"
}

locals {
  github_keys = [for k in split("\n", data.http.github_keys.response_body) : trimspace(k) if trimspace(k) != ""]
  runner_keys = var.runner_ssh_public_key != "" ? [var.runner_ssh_public_key] : []
  ssh_keys    = sort(concat(local.github_keys, local.runner_keys))
}

resource "proxmox_virtual_environment_download_file" "debian_ct_template" {
  content_type = "vztmpl"
  datastore_id = var.image_datastore
  node_name    = var.minecraft_pve_node
  url          = var.debian_ct_template_url
  overwrite    = false
}

resource "proxmox_virtual_environment_container" "minecraft" {
  node_name     = var.minecraft_pve_node
  vm_id         = var.minecraft_vmid
  description   = "MeatballCraft server (configured by the minecraft Ansible role)"
  tags          = sort(["lxc", "minecraft"])
  unprivileged  = true
  start_on_boot = true

  cpu {
    cores = var.minecraft_cores
  }

  memory {
    dedicated = var.minecraft_memory
    swap      = var.minecraft_swap
  }

  disk {
    datastore_id = var.vm_datastore
    size         = var.minecraft_disk_size
  }

  network_interface {
    name   = "eth0"
    bridge = var.network_bridge
  }

  initialization {
    hostname = var.minecraft_hostname

    ip_config {
      ipv4 {
        address = "${var.minecraft_ip}/${var.network_cidr}"
        gateway = var.network_gateway
      }
    }

    dns {
      servers = var.nameservers
    }

    user_account {
      keys = local.ssh_keys
    }
  }

  operating_system {
    template_file_id = proxmox_virtual_environment_download_file.debian_ct_template.id
    type             = "debian"
  }

  lifecycle {
    ignore_changes = [
      operating_system[0].template_file_id,
      initialization[0].user_account,
    ]
  }
}
