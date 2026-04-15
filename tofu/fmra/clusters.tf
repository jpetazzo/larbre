locals {
  fmra_nodes = {
    for vmid, vmdata in local.all_vms:
    vmid => vmdata
    if lookup(vmdata, "talos_cluster", null) == "fmra"
  }
  test_nodes = {
    for vmid, vmdata in local.all_vms:
    vmid => vmdata
    if lookup(vmdata, "talos_cluster", null) == "test"
  }
}

module "fmra" {
  source = "./talop"
  kubernetes_nodes = local.fmra_nodes
  kubernetes_ipv4_svccidr = "10.11.0.0/16"
  kubernetes_ipv4_podcidr = "10.12.0.0/16"
  kubernetes_ipv6_svccidr = "fd11::/112"
  kubernetes_ipv6_podcidr = "fd22::/112"
  proxmox_cluster_name = "larbre"
  proxmox_api_endpoint = "https://192.168.1.201:8006/api2/json"
  talos_cluster_name = "fmra"
}

resource "local_file" "kubeconfig_fmra" {
  filename = "kubeconfig.fmra"
  content = module.fmra.kubeconfig
  file_permission = "0600"
}

resource "local_file" "talosconfig_fmra" {
  filename = "talosconfig.fmra"
  content = module.fmra.talosconfig
  file_permission = "0600"
}

module "test" {
  source = "./talop"
  kubernetes_nodes = local.test_nodes
  proxmox_cluster_name = "larbre"
  proxmox_api_endpoint = "https://192.168.1.201:8006/api2/json"
  talos_cluster_name = "test"
  #talos_version = 
}

resource "local_file" "talosconfig_test" {
  filename = "talosconfig.test"
  content = module.test.talosconfig
  file_permission = "0600"
}
