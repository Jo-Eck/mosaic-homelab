# Consumed by the tofu/talos module via terraform_remote_state.
output "talos_nodes" {
  description = "Full Talos node topology (role, ip, pve_node, ...)"
  value       = var.talos_nodes
}

output "cluster_name" {
  value = var.cluster_name
}

output "controlplane_ips" {
  value = [for k, v in var.talos_nodes : v.ip if v.role == "controlplane"]
}

output "worker_ips" {
  value = [for k, v in var.talos_nodes : v.ip if v.role == "worker"]
}

output "vm_ids" {
  value = { for k, v in proxmox_virtual_environment_vm.talos : k => v.vm_id }
}
