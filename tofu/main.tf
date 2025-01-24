variable "vms" {
  default = {
    dodge = {
      vm_id     = 101,
      memory_mb = 500,
      cpu_cores = 1,
      disk_gb   = 20,
      hypervisor = "kansas",
    },
    topeka = {
      vm_id     = 102,
      memory_mb = 8192,
      cpu_cores = 2,
      disk_gb   = 100,
      hypervisor = "kansas",
    },
    lawrence = {
      vm_id     = 103,
      memory_mb = 3072,
      cpu_cores = 2,
      disk_gb   = 50,
      hypervisor = "kansas",
    },
    wichita = {
      vm_id     = 104,
      memory_mb = 8192,
      cpu_cores = 2,
      disk_gb   = 50,
      hypervisor = "kansas",
    },
    spv = {
      vm_id     = 105,
      memory_mb = 1024,
      cpu_cores = 1,
      disk_gb   = 100,
      hypervisor = "kansas",
    },
    byebyecloudflareimages = {
      vm_id     = 107,
      memory_mb = 4096,
      cpu_cores = 3,
      disk_gb   = 1535,
      hypervisor = "colorado",
    },
  }
}

locals {
  vms = {
    for hostname, vm in var.vms : hostname => {
      hostname       = hostname,
      hypervisor     = vm.hypervisor,
      vm_id          = vm.vm_id,
      memory_mb      = vm.memory_mb,
      cpu_cores      = vm.cpu_cores,
      disk_gb        = vm.disk_gb,
      sshkey_private = format("../sshkeys/sshkey.%s", vm.vm_id),
      sshkey_public  = format("../sshkeys/sshkey.%s.pub", vm.vm_id),
      ipv4_addr      = format("192.168.1.%s", vm.vm_id),
      ipv4_cidr      = "24",
      ipv4_gateway   = "192.168.1.1",
    }
  }
}

resource "tls_private_key" "_" {
  for_each  = local.vms
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "sshkey_private" {
  for_each        = local.vms
  filename        = each.value.sshkey_private
  content         = tls_private_key._[each.key].private_key_pem
  file_permission = "0600"
}

resource "local_file" "sshkey_public" {
  for_each        = local.vms
  filename        = each.value.sshkey_public
  content         = tls_private_key._[each.key].public_key_openssh
  file_permission = "0644"
}

resource "local_file" "ansible_inventory" {
  filename = "../ansible/inventory/20_guests"
  content = join("", formatlist("%s\n", concat([ "[guests]" ], [
    for key, value in local.vms : format("%s ansible_host=%s ansible_user=ubuntu ansible_ssh_private_key_file=%s", value.hostname, value.ipv4_addr, value.sshkey_private)
  ])))
  file_permission = "0644"
}

resource "proxmox_virtual_environment_vm" "_" {
  for_each  = local.vms
  vm_id     = each.value.vm_id
  name      = each.value.hostname
  node_name = each.value.hypervisor

  initialization {
    datastore_id = "local-zfs"
    user_account {
      username = "ubuntu"
      # trimspace() is necessary; without it, the terraform provider
      # thinks that the SSH keys have changed and the instance must be replaced
      keys = [trimspace(tls_private_key._[each.key].public_key_openssh)]
    }
    ip_config {
      ipv4 {
        address = format("%s/%s", each.value.ipv4_addr, each.value.ipv4_cidr)
        gateway = each.value.ipv4_gateway
      }
    }
  }

  memory {
    dedicated = each.value.memory_mb
  }

  operating_system {
    type = "l26"
  }

  cpu {
    cores = each.value.cpu_cores
    type = "x86-64-v2-AES"
  }

  disk {
    datastore_id = "local-zfs"
    file_id      = proxmox_virtual_environment_download_file.ubuntu_2404_20240821.id
    interface    = "virtio0"
    size         = each.value.disk_gb
    discard      = "on"
  }

  network_device {
    bridge = "vmbr1"
  }

  network_device {
    bridge = "vmbr2"
  }
}

resource "proxmox_virtual_environment_download_file" "ubuntu_2404_20240821" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = "kansas"
  url          = "https://cloud-images.ubuntu.com/releases/24.04/release-20240821/ubuntu-24.04-server-cloudimg-amd64.img"
  file_name    = "ubuntu_2404_20240821.img"
}

resource "proxmox_virtual_environment_download_file" "ubuntu_2404_20240821_colorado" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = "colorado"
  url          = "https://cloud-images.ubuntu.com/releases/24.04/release-20240821/ubuntu-24.04-server-cloudimg-amd64.img"
  file_name    = "ubuntu_2404_20240821.img"
}
