# MeatballCraft (Minecraft 1.12.2 / Forge) runs in a native, unprivileged LXC on
# the Legion node (i7-8750H — strong single-thread, which 1.12.2's tick loop
# needs far more than core count). It lives in THIS module (all PVE guests)
# rather than a separate one so it reuses the provider/secrets/backend and the
# existing plan/apply/drift CI matrix. Tofu only creates the container; the JDK,
# modpack, JVM flags and systemd unit are the `minecraft` Ansible role in hosts/.
#
# WORLD SAFETY: the world lives on this container's rootfs, so destroying or
# recreating the container deletes it. The lifecycle.ignore_changes below stops a
# template/key change from silently forcing a replace. Still take a backup (PVE
# vzdump or the role's world backup) before any deliberate replace.

# Seed root SSH keys so the Pi runner can reach the box with Ansible. Pulled from
# the same GitHub user the ssh_hardening role uses, and sorted so upstream key
# reordering never shows up as Tofu drift (only real add/remove does).
data "http" "minecraft_ssh_keys" {
  url = "https://github.com/${var.ssh_key_github_user}.keys"
}

locals {
  minecraft_ssh_keys = sort([
    for k in split("\n", data.http.minecraft_ssh_keys.response_body) : trimspace(k)
    if trimspace(k) != ""
  ])
}

# Debian LXC template on the node's image datastore (same `local` store used for
# the Talos ISO). Pin/bump the URL deliberately, like talos_version.
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
  description   = "MOSAIC MeatballCraft server — configured by the `minecraft` Ansible role"
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
      keys = local.minecraft_ssh_keys
    }
  }

  operating_system {
    template_file_id = proxmox_virtual_environment_download_file.debian_ct_template.id
    type             = "debian"
  }

  lifecycle {
    # A template bump or upstream SSH-key change must never recreate the
    # container (that would destroy the world). Deliberate cpu/memory/disk edits
    # still apply in place.
    ignore_changes = [
      operating_system[0].template_file_id,
      initialization[0].user_account,
    ]
  }
}
