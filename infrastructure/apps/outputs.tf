output "minecraft_ip" {
  value = var.minecraft_ip
}

output "minecraft_vmid" {
  value = proxmox_virtual_environment_container.minecraft.vm_id
}
