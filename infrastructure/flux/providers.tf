terraform {
  required_version = ">= 1.10.0"

  required_providers {
    flux = {
      source  = "fluxcd/flux"
      version = "~> 1.4"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.3"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    sops = {
      source  = "carlpett/sops"
      version = "~> 1.1"
    }
  }
}

provider "github" {
  owner = var.github_owner
  token = var.github_token
}

provider "kubernetes" {
  host                   = local.kube.host
  cluster_ca_certificate = local.kube.ca
  client_certificate     = local.kube.client_cert
  client_key             = local.kube.client_key
}

provider "flux" {
  kubernetes = {
    host                   = local.kube.host
    cluster_ca_certificate = local.kube.ca
    client_certificate     = local.kube.client_cert
    client_key             = local.kube.client_key
  }
  git = {
    url    = "ssh://git@github.com/${var.github_owner}/${var.github_repository}.git"
    branch = var.github_branch
    ssh = {
      username    = "git"
      private_key = tls_private_key.flux.private_key_pem
    }
  }
}
