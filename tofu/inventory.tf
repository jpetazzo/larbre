locals {
  inventory     = yamldecode(file("../inventory.yaml"))
  proxmox_nodes = local.inventory.hypervisors
  all_vms = {
    for vmid, vmdata in local.inventory.vms :
    vmid => merge(vmdata, {
      ipv4_addr        = "192.168.1.${vmid}"
      ipv4_cidr        = 24
      ipv4_gateway     = "192.168.1.1"
      vmnet1_ipv6_addr = "2600:1700:ce90:1490:${vmid}::1/64"
      vmnet2_ipv6_addr = "2600:8803:5e4c:4200:${vmid}::1/64"
    })
  }
}

