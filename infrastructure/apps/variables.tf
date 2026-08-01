# --- Proxmox API / LAN (mirrors the proxmox module defaults) -------------
variable "proxmox_endpoint" {
  type    = string
  default = "https://topton.<tailnet>.ts.net:8006"
}

variable "proxmox_insecure" {
  type    = bool
  default = true
}

variable "network_bridge" {
  type    = string
  default = "LocalLan"
}

variable "network_gateway" {
  type    = string
  default = "192.168.8.1"
}

variable "network_cidr" {
  type    = string
  default = "24"
}

variable "nameservers" {
  type    = list(string)
  default = ["192.168.8.1"]
}

variable "image_datastore" {
  type    = string
  default = "local"
}

variable "vm_datastore" {
  type    = string
  default = "local-lvm"
}

variable "debian_ct_template_url" {
  description = "Debian LXC template; bump deliberately (older point releases get pruned)."
  type        = string
  default     = "http://download.proxmox.com/images/system/debian-13-standard_13.6-1_amd64.tar.zst"
}

# --- SSH access into the containers --------------------------------------
variable "ssh_key_github_user" {
  description = "GitHub user whose public keys seed root SSH (manual Ansible runs)."
  type        = string
  default     = "Jo-Eck"
}

variable "runner_ssh_public_key" {
  description = "Pi runner deploy public key so CI can configure the containers (see docs/bootstrap.md)."
  type        = string
  default     = ""
}

# --- Minecraft LXC -------------------------------------------------------
variable "minecraft_pve_node" {
  type    = string
  default = "legion" # faster single-thread, which 1.12.2 needs
}

variable "minecraft_vmid" {
  type    = number
  default = 8100
}

variable "minecraft_hostname" {
  type    = string
  default = "meatballcraft"
}

variable "minecraft_cores" {
  type    = number
  default = 4
}

variable "minecraft_memory" {
  type    = number
  default = 12288 # MiB
}

variable "minecraft_swap" {
  type    = number
  default = 2048 # MiB
}

variable "minecraft_disk_size" {
  type    = number
  default = 32 # GiB, resizable later
}

variable "minecraft_ip" {
  type    = string
  default = "192.168.8.44" # below the DHCP pool, next to the Talos VMs
}
