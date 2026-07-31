variable "proxmox_endpoint" {
  description = "Proxmox API endpoint, e.g. https://topton.<tailnet>.ts.net:8006"
  type        = string
  default     = "https://topton.<tailnet>.ts.net:8006"
}

variable "proxmox_insecure" {
  description = "Skip TLS verification (true for self-signed PVE certs)"
  type        = bool
  default     = true
}

variable "cluster_name" {
  type    = string
  default = "mosaic"
}

# --- Talos image (built via https://factory.talos.dev) --------------------
variable "talos_version" {
  description = "Talos version; keep in sync with infrastructure/talos and .mise.toml"
  type        = string
  default     = "v1.13.7" # keep in sync with infrastructure/talos + .mise.toml talosctl
}

variable "talos_schematic_id" {
  description = <<-EOT
    Talos Image Factory schematic ID. Create one at https://factory.talos.dev
    with at least the `siderolabs/qemu-guest-agent` system extension so the VMs
    report their IP to Proxmox.
  EOT
  type        = string
  default     = "ce4c980550dd2ab1b17bbf2b08801c7eb59418eafe8f279833297925d67c7515"
}

# --- Networking -----------------------------------------------------------
variable "network_bridge" {
  type    = string
  default = "LocalLan"
}

variable "network_gateway" {
  type    = string
  default = "192.168.8.1"
}

variable "network_cidr" {
  description = "Prefix length for node IPs"
  type        = string
  default     = "24"
}

variable "nameservers" {
  type    = list(string)
  default = ["192.168.8.1"]
}

# --- Datastores on the PVE nodes ------------------------------------------
variable "image_datastore" {
  description = "Datastore that holds the downloaded Talos ISO"
  type        = string
  default     = "local"
}

variable "vm_datastore" {
  description = "Datastore that holds VM disks"
  type        = string
  default     = "local-lvm"
}

# --- Talos node topology (1 control-plane + 3 workers) --------------------
# Two physical hosts (topton .20, legion .10). Static IPs sit below the DHCP
# pool (starts at .100); we start at .40 because the Pi currently holds .51.
# MACs are pinned so you can add matching DHCP reservations on the router —
# Talos boots the ISO via DHCP in maintenance mode, and the reservation makes
# each node come up at the IP below on first boot (see docs/bootstrap.md).
variable "talos_nodes" {
  description = "Talos VM definitions keyed by hostname"
  type = map(object({
    role      = string # "controlplane" | "worker"
    pve_node  = string # "topton" | "legion"
    vmid      = number
    cores     = number
    memory    = number # MiB
    disk_size = number # GiB
    ip        = string # static IPv4, no prefix
    mac       = optional(string)
  }))
  default = {
    "talos-cp-1" = { role = "controlplane", pve_node = "topton", vmid = 8000, cores = 4, memory = 8192, disk_size = 40, ip = "192.168.8.40", mac = "BC:24:11:00:00:40" }
    "talos-w-1"  = { role = "worker", pve_node = "topton", vmid = 8001, cores = 4, memory = 12288, disk_size = 80, ip = "192.168.8.41", mac = "BC:24:11:00:00:41" }
    "talos-w-2"  = { role = "worker", pve_node = "legion", vmid = 8002, cores = 4, memory = 12288, disk_size = 80, ip = "192.168.8.42", mac = "BC:24:11:00:00:42" }
    "talos-w-3"  = { role = "worker", pve_node = "legion", vmid = 8003, cores = 4, memory = 12288, disk_size = 80, ip = "192.168.8.43", mac = "BC:24:11:00:00:43" }
  }
}

# --- Minecraft LXC (MeatballCraft, MC 1.12.2 / Forge) --------------------
# A native, unprivileged Debian LXC on the Legion node. Sized for a heavy
# 1.12.2 expert pack (8G heap + headroom). The in-container server (JDK,
# modpack, systemd unit) is the `minecraft` Ansible role in hosts/. The static
# IP sits below the DHCP pool alongside the Talos VMs (.40-.43 = Talos,
# .44 = this container, .51 = Pi).
variable "minecraft_pve_node" {
  description = "PVE node that hosts the Minecraft LXC (Legion = faster single-thread)"
  type        = string
  default     = "legion"
}

variable "minecraft_vmid" {
  description = "Proxmox guest ID for the Minecraft LXC"
  type        = number
  default     = 8100
}

variable "minecraft_hostname" {
  type    = string
  default = "meatballcraft"
}

variable "minecraft_cores" {
  description = "vCPU cores for the LXC (1.12.2 is single-thread bound; 4 is plenty)"
  type        = number
  default     = 4
}

variable "minecraft_memory" {
  description = "LXC RAM in MiB (8G heap + ~4G for metaspace/off-heap/OS)"
  type        = number
  default     = 12288
}

variable "minecraft_swap" {
  description = "LXC swap in MiB"
  type        = number
  default     = 2048
}

variable "minecraft_disk_size" {
  description = "LXC rootfs size in GiB (grows with the dimension-heavy world; resizable later)"
  type        = number
  default     = 32
}

variable "minecraft_ip" {
  description = "Static IPv4 (no prefix) for the LXC, below the DHCP pool"
  type        = string
  default     = "192.168.8.44"
}

variable "ssh_key_github_user" {
  description = "GitHub user whose public keys seed root SSH on the LXC for Ansible (matches hosts/group_vars/all.yml)"
  type        = string
  default     = "Jo-Eck"
}

variable "debian_ct_template_url" {
  description = <<-EOT
    Debian LXC template URL, downloaded to the node's image datastore. Pin/bump
    deliberately — verify the current filename at
    http://download.proxmox.com/images/system/ (older point releases get pruned).
  EOT
  type        = string
  default     = "http://download.proxmox.com/images/system/debian-12-standard_12.7-1_amd64.tar.zst"
}
