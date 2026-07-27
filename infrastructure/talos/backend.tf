# Separate state file from the proxmox module, same B2 bucket.
terraform {
  backend "s3" {
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

    # No state locking — B2 doesn't support the conditional PutObject that
    # `use_lockfile` needs (501 NotImplemented). See proxmox/backend.tf.
  }
}
