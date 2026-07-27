# Talos machine-config patches

Talos machine configs are assembled in `infrastructure/talos` from three layers, in order:

1. **`all.yaml`** — applied to every node (time, kubelet, KubePrism). Networking
   uses Talos defaults (Flannel CNI + kube-proxy).
2. **`controlplane.yaml`** / **`worker.yaml`** — role-specific settings.
3. **Generated per-node patch** — hostname, static IP, install disk and
   certSANs, produced from the topology map in `infrastructure/proxmox/variables.tf`
   (`talos_nodes`). This is the single source of truth for addressing, so there
   are no per-node YAML files to keep in sync here.

To change a node's IP or which host it runs on, edit `talos_nodes` in
`infrastructure/proxmox/variables.tf` (or your `terraform.tfvars`), not this directory.
