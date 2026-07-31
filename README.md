# MOSAIC

<img src="Mosaic.png" alt="MOSAIC logo" width="300">

_"We do what we must, because we can." — GLaDOS_

My home cluster, managed as code. Two Proxmox nodes and a Raspberry Pi run a
four-node Talos Kubernetes cluster, and everything here is applied by a GitOps
pipeline instead of by hand in the web UI.

It sits behind a DS-Lite connection with no public IPv4, so it is only reachable
over Tailscale. The automation runs on the Pi, which is always on the tailnet.

## Hardware

- Topton i3-N305: Proxmox node
- Lenovo Legion Y530: Proxmox node
- Raspberry Pi: corosync QDevice (quorum), jump host, and CI runner

## How it's built

- Ansible configures the two Proxmox hosts and the Pi.
- OpenTofu with `bpg/proxmox` creates the VMs.
- OpenTofu with `siderolabs/talos` installs and bootstraps Talos: one
  control-plane, three workers, default Flannel networking.
- Flux runs the in-cluster add-ons and apps.
- Secrets are encrypted with SOPS + age; Tofu state lives in Backblaze B2.

## Layout

```
hosts/           Proxmox host and Pi config
infrastructure/  proxmox (VMs) and talos (cluster + machine-config patches)
gitops/          Flux entrypoints, infrastructure, apps
.github/         plan / apply / drift workflows (Pi runner)
docs/            bootstrap runbook
```

## Access

I log in as `jon` with an SSH key, and the sudo password comes from a password
manager. The automation never uses my login: Tofu reaches Proxmox through a
scoped API token, Flux decrypts with its own age key inside the cluster, and the
runner holds the state and secret keys. Host changes still go through Ansible by
hand, since they can affect cluster quorum.

## TODO

- make application of ansible passwordless
- graphana dashboard
- fix statelocking in b2
- minecraft lxc — MeatballCraft (Cleanroom/Java 25): Tofu LXC + `minecraft` Ansible role done; needs server-pack URL
- arr stack

## Getting started

See [docs/bootstrap.md](docs/bootstrap.md).
