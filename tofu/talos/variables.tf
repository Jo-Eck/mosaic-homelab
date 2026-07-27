variable "talos_version" {
  description = "Talos version (keep in sync with tofu/proxmox and .mise.toml)"
  type        = string
  default     = "v1.10.4"
}

variable "kubernetes_version" {
  description = "Kubernetes version Talos installs (must be compatible with talos_version)"
  type        = string
  default     = "v1.32.3"
}

variable "network_cidr" {
  type    = string
  default = "24"
}

variable "network_gateway" {
  type    = string
  default = "192.168.8.1"
}

variable "nameservers" {
  type    = list(string)
  default = ["192.168.8.1"]
}

variable "install_disk" {
  description = "Disk Talos installs to inside the VM (scsi0 -> /dev/sda)"
  type        = string
  default     = "/dev/sda"
}
