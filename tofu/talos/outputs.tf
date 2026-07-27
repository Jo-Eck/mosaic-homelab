output "kubeconfig" {
  description = "Raw kubeconfig for the cluster"
  value       = data.talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
}

output "talosconfig" {
  description = "talosctl client configuration"
  value       = data.talos_client_configuration.this.talos_config
  sensitive   = true
}

output "cluster_endpoint" {
  value = local.cluster_endpoint
}

output "controlplane_ip" {
  value = local.cp_ip
}

output "worker_ips" {
  value = [for k, v in local.workers : v.ip]
}
