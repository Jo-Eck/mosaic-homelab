locals {
  # metal ISO from the factory, pinned to your schematic + Talos version
  talos_iso_url = "https://factory.talos.dev/image/${var.talos_schematic_id}/${var.talos_version}/metal-amd64.iso"

  # Unique set of PVE nodes that need a copy of the image
  pve_nodes = toset([for n in var.talos_nodes : n.pve_node])
}

# Download the Talos ISO onto each PVE node's image datastore.
resource "proxmox_virtual_environment_download_file" "talos_iso" {
  for_each = local.pve_nodes

  content_type = "iso"
  datastore_id = var.image_datastore
  node_name    = each.value
  url          = local.talos_iso_url
  file_name    = "talos-${var.talos_version}-${substr(var.talos_schematic_id, 0, 8)}.iso"
  overwrite    = false
}
