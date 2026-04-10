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
  endpoint = "https://colorado:8006/"
  # TODO: use terraform variable or remove the line, and use PROXMOX_VE_USERNAME environment variable
  #username = "root@pam"
  # TODO: use terraform variable or remove the line, and use PROXMOX_VE_PASSWORD environment variable
  #password = "the-password-set-during-installation-of-proxmox-ve"
  # because self-signed TLS certificate is in use
  insecure = true
  # uncomment (unless on Windows...)
  # tmp_dir  = "/var/tmp"

  #ssh {
  #  agent = true
  #  # TODO: uncomment and configure if using api_token instead of password
  #  # username = "root"
  #}
}
