variable "talos_cluster_name" {
  type = string
  default = null
  description = "Short, alphanumeric identifier for the cluster. This will be used to name some Proxmox resources, so don't put fancy characters in there."
}

resource "random_string" "talos_cluster_name" {
  length = 4
  lower = true
  upper = false
  numeric = false
  special = false
}

locals {
  talos_cluster_name = coalesce(
    var.talos_cluster_name,
    random_string.talos_cluster_name.result
  )
}

variable "talos_version" {
  type = string
  default = null
}

data "talos_image_factory_versions" "_" {
  filters = {
    stable_versions_only = true
  }
}

locals {
  talos_version = coalesce(
    var.talos_version,
    element(data.talos_image_factory_versions._.talos_versions, -1)
  )
}

variable "talos_extensions" {
  type = list(string)
  default = []
}

variable "kubernetes_nodes" {
  # Note: the key in the map will be the Proxmox VM ID.
  type = map(object({
    hostname = string,
    hypervisor = string,
    memory_mb = number,
    cpu_cores = number,
    disk_gb = number,
    machine_type = string,
    networking = list(object({
      bridge = string,
      ipv4_addr = string,
      ipv4_cidr = number,
      ipv4_gateway = optional(string),
      ipv6_addr = string,
    }))
  }))
}

variable "kubernetes_api_endpoint" {
  type = string
  default = null
  description = "Something like https://k8s-api-lb:6443. If it's not set, we'll just use the first controlplane node."
}

locals {
  kubernetes_api_endpoint = coalesce(
    var.kubernetes_api_endpoint,
    "https://${local.first_node.networking[0].ipv4_addr}:6443"
  )
}

variable "proxmox_api_endpoint" {
  type = string
  description = "Something like https://X.X.X.X:8006/api2/json"
}

variable "proxmox_cluster_name" {
  type = string
  default = "pve"
  description = "Used by the CSI driver. You can set this to anything you'd like (ideally your actual Proxmox cluster name)."
}

variable "kubernetes_ipv4_svccidr" {
  type = string
  default = null
}

variable "kubernetes_ipv4_podcidr" {
  type = string
  default = null
}

variable "kubernetes_ipv4_cidrsize" {
  type = number
  default = 24
}

variable "kubernetes_ipv6_svccidr" {
  type = string
  default = null
}

variable "kubernetes_ipv6_podcidr" {
  type = string
  default = null
}

variable "kubernetes_ipv6_cidrsize" {
  type = number
  default = 120
}

resource "random_integer" "cidr_base" {
  min = 1
  max = 128
}

locals {
  kubernetes_ipv4_svccidr = coalesce(
    var.kubernetes_ipv4_svccidr,
    "10.${2*random_integer.cidr_base.result - 1}.0.0/16"
  )
  kubernetes_ipv4_podcidr = coalesce(
    var.kubernetes_ipv4_svccidr,
    "10.${2*random_integer.cidr_base.result}.0.0/16"
  )
  kubernetes_ipv4_cidrsize = var.kubernetes_ipv4_cidrsize
  kubernetes_ipv6_svccidr = coalesce(
    var.kubernetes_ipv6_svccidr,
    "fddf:${2*random_integer.cidr_base.result - 1}::/112"
  )
  kubernetes_ipv6_podcidr = coalesce(
    var.kubernetes_ipv6_podcidr,
    "fddf:${2*random_integer.cidr_base.result}::/112"
  )
  kubernetes_ipv6_cidrsize = var.kubernetes_ipv6_cidrsize
}

# And all the stuff that gets passed "as-is".

locals {
  talos_extensions = var.talos_extensions
  kubernetes_nodes = var.kubernetes_nodes
  proxmox_api_endpoint = var.proxmox_api_endpoint
  proxmox_cluster_name = var.proxmox_cluster_name
}
