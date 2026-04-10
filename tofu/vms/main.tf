locals {
  vms = { 
    for vmid, vmdata in local.all_vms:
    vmid => vmdata
    if can(vmdata.image)
  }
}

resource "proxmox_virtual_environment_download_file" "_" {
  for_each = {
    for pair in setproduct(
      local.proxmox_nodes,
      keys(local.inventory.images)
      ):
    "${pair[0]}/${pair[1]}" => {
      node = pair[0]
      image = pair[1]
      url = local.inventory.images[pair[1]]
    }
  }
  content_type = "iso"
  datastore_id = "local"
  node_name    = each.value.node
  url          = local.inventory.images[each.value.image]
  file_name    = "${each.value.image}.img"
}

resource "tls_private_key" "_" {
  for_each  = local.vms
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "sshkey_private" {
  for_each        = local.vms
  filename        = "../../sshkeys/sshkey.${each.key}"
  content         = tls_private_key._[each.key].private_key_pem
  file_permission = "0600"
}

resource "local_file" "sshkey_public" {
  for_each        = local.vms
  filename        = "../../sshkeys/sshkey.${each.key}.pub"
  content         = tls_private_key._[each.key].public_key_openssh
  file_permission = "0644"
}

/*
resource "local_file" "ansible_inventory" {
  filename = "../../ansible/inventory/20_guests"
  content = join("", formatlist("%s\n", concat(["[guests]"], [
    for key, value in local.vms : format("%s ansible_host=%s ansible_user=ubuntu ansible_ssh_private_key_file=%s", value.hostname, value.ipv4_addr, value.sshkey_private)
  ])))
  file_permission = "0644"
}
*/

resource "proxmox_virtual_environment_vm" "_" {
  for_each  = local.vms
  vm_id     = each.key
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
        address = "${each.value.ipv4_addr}/${each.value.ipv4_cidr}"
        gateway = "${each.value.ipv4_gateway}"
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
    type  = "x86-64-v2-AES"
  }

  disk {
    datastore_id = "local-zfs"
    file_id      = proxmox_virtual_environment_download_file._["${each.value.hypervisor}/${each.value.image}"].id
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
