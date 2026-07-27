# Render a machine configuration per node = common patch + role patch + the
# generated per-node patch (hostname / static IP / install disk / certSANs).
data "talos_machine_configuration" "this" {
  for_each = local.nodes

  cluster_name       = local.cluster_name
  cluster_endpoint   = local.cluster_endpoint
  machine_type       = each.value.role
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  config_patches = [
    file("${path.module}/patches/all.yaml"),
    file("${path.module}/patches/${each.value.role}.yaml"),
    local.node_patches[each.key],
    local.hostname_patches[each.key],
  ]
}

# Push the config to each node (nodes boot the ISO in maintenance mode first).
resource "talos_machine_configuration_apply" "this" {
  for_each = local.nodes

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.this[each.key].machine_configuration
  node                        = each.value.ip
  endpoint                    = each.value.ip
}
