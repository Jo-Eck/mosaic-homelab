# Backblaze B2 remote state, separate key so app-container lifecycle is decoupled
# from the platform (proxmox/talos) state. Same no-locking caveat as the other
# modules — a single serial runner means no concurrent writers.
terraform {
  backend "s3" {
    bucket = "mosaic-tofu-state"
    key    = "apps/terraform.tfstate"
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
