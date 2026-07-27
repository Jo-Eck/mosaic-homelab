# Talos VMs: boot the ISO (maintenance mode), then the tofu/talos module applies
# machine config which installs Talos to scsi0. Static IPs come from the
# generated per-node patches in tofu/talos (single source of truth), not cloud-init.
resource "proxmox_virtual_environment_vm" "talos" {
  for_each = var.talos_nodes

  name        = each.key
  description = "MOSAIC Talos ${each.value.role}"
  node_name   = each.value.pve_node
  vm_id       = each.value.vmid
  tags        = sort(["talos", each.value.role])

  # qemu-guest-agent is provided by the factory schematic extension
  agent {
    enabled = true
  }

  stop_on_destroy = true

  # Required for per-disk iothread below
  scsi_hardware = "virtio-scsi-single"

  cpu {
    cores = each.value.cores
    type  = "host"
  }

  memory {
    dedicated = each.value.memory
  }

  disk {
    datastore_id = var.vm_datastore
    interface    = "scsi0"
    size         = each.value.disk_size
    file_format  = "raw"
    ssd          = true
    discard      = "on"
    iothread     = true
  }

  cdrom {
    file_id   = proxmox_virtual_environment_download_file.talos_iso[each.value.pve_node].id
    interface = "ide2"
  }

  network_device {
    bridge      = var.network_bridge
    mac_address = each.value.mac
  }

  operating_system {
    type = "l26"
  }

  # Empty disk first boot -> falls through to the ISO (maintenance mode).
  # Once Talos is installed, scsi0 boots first.
  boot_order = ["scsi0", "ide2"]

  lifecycle {
    # Don't recreate VMs when the ISO reference changes after install
    ignore_changes = [cdrom]
  }
}
