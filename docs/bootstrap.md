# MOSAIC bootstrap runbook

The day-0 steps to go from bare Proxmox hosts to a GitOps-managed Talos cluster.
Everything here is manual and done **once**; after that, PRs + the Pi runner do
the work. Run the CLI steps from a machine on the tailnet (your workstation or
the Pi).

## 0. Prerequisites

- Proxmox VE installed on **topton** and **legion**, clustered, with the **Pi**
  providing the corosync **QDevice** (already set up — we don't touch it).
- **Tailscale** on topton, legion, and the Pi. Note their MagicDNS names.
- Personal GitHub access to `Jo-Eck/MOSAIC` from your workstation.
- SSH to the hosts as **`jon`** with your key; sudo password from your password
  manager (Ansible prompts via `-K`). The `ssh_hardening` role authorizes your
  keys from `https://github.com/Jo-Eck.keys` (set `github_ssh_key_user`).
- Tools installed (`mise install` uses `.mise.toml`): `tofu`, `talosctl`,
  `kubectl`, `helm`, `flux`, `sops`, `age`.

## Network plan

Everything is on one flat LAN — `192.168.8.0/24`, bridged via `vmbr0`, so VMs
and LXC share the subnet with the hosts. The router's DHCP pool starts at
`.100`, so `.1–.99` is free for static addressing:

| Purpose | IP |
|---------|----|
| Gateway (router) | 192.168.8.1 |
| legion / topton hosts | .10 / .20 |
| Raspberry Pi (`raspi`) | DHCP; reached over Tailscale |
| talos-cp-1 | .40 |
| talos-w-1 / w-2 / w-3 | .41 / .42 / .43 |
| Reserved for Service LoadBalancers (MetalLB, later) | .60–.99 |
| Router DHCP pool | .100+ |

The hosts + Pi are also on **Tailscale** (`legion` / `topton` / `raspi` under
`<tailnet>.ts.net`); Ansible and the Proxmox provider address them by those
names. The **Talos VMs are LAN-only** (not on Tailscale) — the runner reaches
them at their `.4x` IPs.

Add **DHCP reservations** on the router mapping each Talos VM's pinned MAC
(`BC:24:11:00:00:4x`) to its `.4x` address — see step 6. (Node IPs start at
`.40` because the Pi currently occupies `.51`.)

## 1. Age keys (the trust anchors)

```bash
age-keygen -o infra.agekey      # for Tofu + Ansible (lives on the Pi)
age-keygen -o cluster.agekey    # for Flux (lives in-cluster)
```

- Copy the **public** keys (`age1...`) into `.sops.yaml`, replacing
  `<INFRA_AGE_PUBKEY>` and `<CLUSTER_AGE_PUBKEY>`.
- **Back both private keys up offline** (password manager / paper). If you lose
  them, every encrypted secret is unrecoverable.

## 2. Proxmox API token + Talos image

- In the PVE UI: **Datacenter → Permissions → API Tokens**, create
  `tofu@pve!mosaic` with a role that can manage VMs/storage. Note the secret.
- Build a Talos image at <https://factory.talos.dev> including the
  **`siderolabs/qemu-guest-agent`** extension. Note the **schematic ID**.
- Note your datastores (defaults assume `local` for images, `local-lvm` for
  disks).

## 3. State backend (Backblaze B2)

- Create a **private bucket** `mosaic-tofu-state` and an **application key**
  scoped to it. Note the region + S3 endpoint.
- Adjust `bucket`/`region`/`endpoints` in `infrastructure/*/backend.tf` if they differ.

## 4. The Pi runner

```bash
# From your workstation. Run Ansible from the hosts/ dir so its ansible.cfg
# (inventory, roles, and collections paths) is loaded:
cd hosts
ansible-galaxy collection install -r requirements.yml
ansible-playbook -i inventory/hosts.yml playbooks/pi-runner.yml -K
cd ..
```

Then register + start the runner and give it its secrets. On the Pi:

```bash
# Register (get a token: repo → Settings → Actions → Runners → New self-hosted)
sudo -u actions /opt/actions-runner/config.sh \
  --url https://github.com/Jo-Eck/MOSAIC \
  --token <RUNNER_REGISTRATION_TOKEN> \
  --labels self-hosted,linux,ARM64,mosaic --unattended

# Secrets stay on the Pi: give the runner service an EnvironmentFile
sudo install -d -m 0700 -o actions /home/actions/.config/sops/age
sudo cp infra.agekey /home/actions/.config/sops/age/keys.txt   # infra private key

sudo tee /etc/actions-runner.env >/dev/null <<'EOF'
AWS_ACCESS_KEY_ID=<B2 keyID>
AWS_SECRET_ACCESS_KEY=<B2 applicationKey>
SOPS_AGE_KEY_FILE=/home/actions/.config/sops/age/keys.txt
EOF

# Point the runner service at it, then install + start
cd /opt/actions-runner
sudo ./svc.sh install actions
# add 'EnvironmentFile=/etc/actions-runner.env' to the generated service unit
sudo ./svc.sh start
```

## 5. Fill in configuration

```bash
# Proxmox module
cd infrastructure/proxmox
cp terraform.tfvars.example terraform.tfvars      # set endpoint, schematic id, network
cp secrets.sops.yaml.example secrets.sops.yaml    # set the API token, then:
sops --encrypt --in-place secrets.sops.yaml

# Talos module
cd ../talos
cp terraform.tfvars.example terraform.tfvars      # set versions, gateway, install disk
```

## 6. First apply (manual)

```bash
# Host config (run Ansible from the hosts/ dir so ansible.cfg is loaded)
cd hosts
ansible-playbook -i inventory/hosts.yml playbooks/pve-hosts.yml -K
cd ..

# VMs + Talos image
cd infrastructure/proxmox && tofu init && tofu apply

# Now add DHCP reservations on the router: map each VM MAC (BC:24:11:00:00:4x)
# to its .4x IP. Talos boots the ISO via DHCP in maintenance mode; the
# reservation makes each node reachable at the static IP the next step expects.

# Talos config + bootstrap + kubeconfig (Flannel CNI + kube-proxy come up by default)
cd ../talos && tofu init && tofu apply

# Verify
export TALOSCONFIG=$PWD/../../talosconfig
export KUBECONFIG=$PWD/../../kubeconfig
talosctl health --nodes 192.168.8.40
kubectl get nodes -o wide      # 4 nodes, Ready
```

## 7. Flux bootstrap (one-time setup, then automated)

Flux is bootstrapped by the **`infrastructure/flux`** Tofu module, so a
from-scratch cluster wires itself up to GitOps with **no manual `flux bootstrap`**
— the `flux` job in `apply.yml` (and the `tofu apply` below) handles it, and it's
idempotent. Two one-time inputs are required:

1. **A GitHub PAT** allowed to add a repo deploy key. Store it as the
   `FLUX_GITHUB_TOKEN` GitHub Actions secret (repo → Settings → Secrets and
   variables → Actions). CI exposes it to Tofu as `TF_VAR_github_token`.

2. **The cluster age private key**, committed *encrypted with the infra key* so
   CI can materialise the `flux-system/sops-age` decryption secret on every
   rebuild:

   ```bash
   cd infrastructure/flux
   cp cluster-age.sops.yaml.example cluster-age.sops.yaml
   # set `agekey:` to the contents of cluster.agekey (AGE-SECRET-KEY-...)
   sops --encrypt --in-place cluster-age.sops.yaml   # infra key, per .sops.yaml
   ```

Then bootstrap Flux (a third module in the manual first apply):

```bash
cd infrastructure/flux
export TF_VAR_github_token=<PAT>      # repo-admin, to register the deploy key
tofu init && tofu apply

flux get kustomizations --watch       # infrastructure -> apps
```

After this, tearing the cluster down and re-running `apply.yml` (proxmox → talos
→ flux) re-bootstraps Flux automatically — no hand steps.

## 8. Hand over to GitOps

- In GitHub: create a **`production` Environment** with yourself as a required
  reviewer (gates `apply.yml` until you trust it).
- From now on: open a PR → `plan.yml` posts the diff → merge → `apply.yml`
  applies infra (proxmox → talos → flux); Flux reconciles the cluster.
  `drift.yml` runs nightly.
- (Optional) enable Renovate to PR version bumps.

---

## Values you must fill in

| Value | Where |
|-------|-------|
| `infra` / `cluster` age **public** keys | `.sops.yaml` |
| Proxmox API token | `infrastructure/proxmox/secrets.sops.yaml` (encrypted) |
| Proxmox endpoint (Tailscale name) | `infrastructure/proxmox/terraform.tfvars` |
| Talos Factory **schematic ID** | `infrastructure/proxmox/terraform.tfvars` |
| LAN gateway / CIDR / nameservers | `infrastructure/{proxmox,talos}/terraform.tfvars` |
| Node IPs / vmids / host placement | `talos_nodes` in `infrastructure/proxmox/variables.tf` |
| DHCP reservations (MAC → IP) | your router |
| Datastore names | `infrastructure/proxmox/terraform.tfvars` |
| Talos / Kubernetes versions | `infrastructure/talos/terraform.tfvars`, `.mise.toml` |
| B2 bucket / region / endpoint | `infrastructure/*/backend.tf` |
| B2 keys + age key path | Pi runner `EnvironmentFile` |
| Flux repo-admin PAT | `FLUX_GITHUB_TOKEN` GitHub Actions secret |
| Cluster age **private** key (encrypted) | `infrastructure/flux/cluster-age.sops.yaml` |
| GitHub user for SSH keys | `hosts/group_vars/all.yml` (`github_ssh_key_user`) |
| Runner version | `hosts/roles/runner/defaults/main.yml` |

## Backup / DR (the short list)

1. **`infra.agekey` + `cluster.agekey`** — offline. Everything else is
   recoverable; these are not.
2. **Tofu state** — lives in B2; enable bucket versioning.
3. Losing the Pi: reinstall, restore `infra.agekey`, re-register the runner —
   the rest rehydrates from git + state.
