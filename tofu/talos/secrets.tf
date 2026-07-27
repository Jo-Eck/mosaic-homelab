# Cluster PKI, secrets and tokens. Sensitive — kept only in encrypted remote
# state. Back up this state (or `talosctl gen secrets` output) offline; losing
# it means you can't manage the cluster without a rebuild.
resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}
