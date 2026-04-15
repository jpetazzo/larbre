terraform {
  backend "local" {
    path = pathexpand("~/Sync/misc/tfstate/fmra.tfstate")
  }
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.99.0"
    }
    talos = {
      source = "siderolabs/talos"
    }
  }
}

provider "proxmox" {
  # Check https://search.opentofu.org/provider/bpg/proxmox/latest#quick-examples
  # We don't need SSH access, which means you can use an API token.
  # We suggest to configure this with environment variables.
}
