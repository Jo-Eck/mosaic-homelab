# Remote state on Backblaze B2 (S3-compatible) — off-site, decoupled from the
# cluster it manages. Access keys come from the environment on the runner:
#   AWS_ACCESS_KEY_ID     = <B2 keyID>
#   AWS_SECRET_ACCESS_KEY = <B2 applicationKey>
#
# Backend blocks can't use variables — adjust bucket/region/endpoint inline or
# pass `-backend-config=...` during `tofu init`.
terraform {
  backend "s3" {
    bucket = "mosaic-tofu-state"
    key    = "proxmox/terraform.tfstate"
    region = "eu-central-003"

    endpoints = {
      s3 = "https://s3.eu-central-003.backblazeb2.com"
    }

    # B2 is not AWS — skip AWS-specific behaviour
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true

    # Native lockfile locking (OpenTofu >= 1.10) — no DynamoDB required
    use_lockfile = true
  }
}
