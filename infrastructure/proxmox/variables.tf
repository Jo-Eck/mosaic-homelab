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
