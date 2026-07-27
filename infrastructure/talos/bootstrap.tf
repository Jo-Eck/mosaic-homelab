# Bootstrap etcd on the (single) control-plane, once its config is applied.
resource "talos_machine_bootstrap" "this" {
  depends_on = [talos_machine_configuration_apply.this]

  node                 = local.cp_ip
  endpoint             = local.cp_ip
  client_configuration = talos_machine_secrets.this.client_configuration
}

# Retrieve kubeconfig + talosconfig after bootstrap.
data "talos_cluster_kubeconfig" "this" {
  depends_on = [talos_machine_bootstrap.this]

  node                 = local.cp_ip
  endpoint             = local.cp_ip
  client_configuration = talos_machine_secrets.this.client_configuration
}

data "talos_client_configuration" "this" {
  cluster_name         = local.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [local.cp_ip]
  nodes                = [for k, v in local.nodes : v.ip]
}

# Drop local files for kubectl/talosctl/flux on the runner (both gitignored).
resource "local_file" "kubeconfig" {
  content         = data.talos_cluster_kubeconfig.this.kubeconfig_raw
  filename        = "${path.module}/../../kubeconfig"
  file_permission = "0600"
}

resource "local_file" "talosconfig" {
  content         = data.talos_client_configuration.this.talos_config
  filename        = "${path.module}/../../talosconfig"
  file_permission = "0600"
}

# Optional gate: wait until the cluster reports healthy. Talos' default Flannel
# CNI + kube-proxy come up on their own after bootstrap.
data "talos_cluster_health" "this" {
  depends_on = [talos_machine_bootstrap.this]

  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [local.cp_ip]
  control_plane_nodes  = [for k, v in local.controlplanes : v.ip]
  worker_nodes         = [for k, v in local.workers : v.ip]

  timeouts = {
    read = "10m"
  }
}
