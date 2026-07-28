# Flux is bootstrapped here so a from-scratch cluster wires itself up to GitOps
# automatically — no manual `flux bootstrap` after every teardown/rebuild. This
# module runs after the talos module (it consumes its kubeconfig); see the
# `flux` job in .github/workflows/apply.yml.

# The Talos node topology + PKI live in the talos module's state; read the admin
# kubeconfig back from there so this module has cluster credentials.
data "terraform_remote_state" "talos" {
  backend = "s3"
  config = {
    bucket = "mosaic-tofu-state"
    key    = "talos/terraform.tfstate"
    region = "eu-central-003"

    endpoints = {
      s3 = "https://s3.eu-central-003.backblazeb2.com"
    }

    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }
}

locals {
  # talos_cluster_kubeconfig returns a full kubeconfig with client-cert auth.
  kubeconfig = yamldecode(data.terraform_remote_state.talos.outputs.kubeconfig)

  kube = {
    host        = local.kubeconfig.clusters[0].cluster.server
    ca          = base64decode(local.kubeconfig.clusters[0].cluster["certificate-authority-data"])
    client_cert = base64decode(local.kubeconfig.users[0].user["client-certificate-data"])
    client_key  = base64decode(local.kubeconfig.users[0].user["client-key-data"])
  }
}

# Repo-scoped SSH deploy key for Flux — preferable to storing an account-wide
# PAT in the cluster. The private half lives in state and in the flux-system
# secret (created by bootstrap); the public half is registered on the repo here.
resource "tls_private_key" "flux" {
  algorithm = "ED25519"
}

resource "github_repository_deploy_key" "flux" {
  title      = "flux-${var.github_repository}"
  repository = var.github_repository
  key        = tls_private_key.flux.public_key_openssh
  read_only  = false # bootstrap pushes the sync manifests back to the repo
}

# Install the Flux controllers, commit the sync manifests under var.flux_path,
# and point the cluster at them. Idempotent: a no-op once in place, a full
# re-install on a fresh cluster.
resource "flux_bootstrap_git" "this" {
  depends_on = [github_repository_deploy_key.flux]

  path    = var.flux_path
  version = var.flux_version
}

# Materialise the cluster age key as flux-system/sops-age so Flux can decrypt
# gitops/**/*.sops.yaml. The key is committed encrypted with the *infra* age key
# (which the runner holds), keeping rebuilds hands-off — see cluster-age.sops.yaml.
data "sops_file" "cluster_age" {
  source_file = "${path.module}/cluster-age.sops.yaml"
}

resource "kubernetes_secret" "sops_age" {
  depends_on = [flux_bootstrap_git.this]

  metadata {
    name      = "sops-age"
    namespace = "flux-system"
  }

  data = {
    "age.agekey" = data.sops_file.cluster_age.data["agekey"]
  }
}
