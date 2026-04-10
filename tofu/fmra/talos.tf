locals {
  factory_url   = "https://factory.talos.dev"
  platform      = "nocloud"
  arch          = "amd64"
  talos_version = "v1.12.6"
  schematic     = file("schematic.yaml")
  schematic_id  = jsondecode(data.http.schematic_id.response_body)["id"]
  image_id      = "${local.schematic_id}_${local.talos_version}"
}

locals {
  fmra_k8s_nodes = {
    for vmid, vmdata in local.all_vms :
    vmid => vmdata if lookup(vmdata, "talos_cluster", "NOPE") == "fmra"
  }
  fmra_k8s_api_endpoint = "https://fmra.larb.re:6443"
  fmra_first_node_id = [ for k,v in local.fmra_k8s_nodes: k if v.machine_type=="controlplane" ][0]
  fmra_first_node = local.fmra_k8s_nodes[local.fmra_first_node_id]
  fmra_kubernetes_version = data.talos_machine_configuration.fmra[local.fmra_first_node_id].kubernetes_version
  proxmox_api_endpoint = "https://192.168.1.201:8006/api2/json" # FIXME use p_v_e_nodes ?
  region = "redlady"
}

data "http" "schematic_id" {
  url          = "${local.factory_url}/schematics"
  method       = "POST"
  request_body = local.schematic
}

resource "proxmox_virtual_environment_download_file" "talos_iso" {
  for_each                = toset(local.proxmox_nodes)
  node_name               = each.value
  content_type            = "iso"
  datastore_id            = "local"
  decompression_algorithm = "gz"
  overwrite               = false
  url                     = "${local.factory_url}/image/${local.schematic_id}/${local.talos_version}/${local.platform}-${local.arch}.raw.gz"
  file_name               = "talos-${local.schematic_id}-${local.talos_version}-${local.platform}-${local.arch}.img"
}

resource "talos_machine_secrets" "fmra" {
  talos_version = local.talos_version
}

data "talos_client_configuration" "fmra" {
  cluster_name         = "fmra"
  client_configuration = talos_machine_secrets.fmra.client_configuration
  nodes                = [for k, v in local.fmra_k8s_nodes : v.ipv4_addr]
  endpoints            = [for k, v in local.fmra_k8s_nodes : v.ipv4_addr if v.machine_type == "controlplane"]
}

data "talos_machine_configuration" "fmra" {
  for_each         = local.fmra_k8s_nodes
  cluster_name     = "fmra"
  cluster_endpoint = local.fmra_k8s_api_endpoint
  talos_version    = local.talos_version
  machine_type     = each.value.machine_type
  machine_secrets  = talos_machine_secrets.fmra.machine_secrets
}

resource "proxmox_virtual_environment_vm" "fmra" {
  for_each    = local.fmra_k8s_nodes
  node_name   = each.value.hypervisor
  name        = each.value.hostname
  description = each.value.machine_type == "controlplane" ? "FMRA Talos Control Plane" : "FMRA Talos Worker"
  tags        = ["fmra"]
  on_boot     = true
  vm_id       = each.key

  bios = "ovmf"
  efi_disk {
    datastore_id = "local-zfs"
  }

  cpu {
    cores = each.value.cpu_cores
    type  = "x86-64-v2-AES"
  }

  # There seems to be a bug either in Proxmox or the Proxmox Terraform provider.
  # Sometimes it detects the architecture has having changed, which causes
  # an update to the VM, which in turn causes a reboot. Let's ignore that field.
  lifecycle {
    ignore_changes = [cpu[0].architecture]
  }

  memory {
    dedicated = each.value.memory_mb
  }

  network_device {
    bridge = "vmbr1"
  }
  network_device {
    bridge = "vmbr2"
  }

  disk {
    datastore_id = "local-zfs"
    interface    = "virtio0"
    discard      = "on"
    size         = each.value.disk_gb
    file_id      = proxmox_virtual_environment_download_file.talos_iso["${each.value.hypervisor}"].id
  }

  boot_order = ["scsi0"]

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id = "local-zfs"
    dns {
      servers = ["1.0.0.1", "1.1.1.1"]
    }
    ip_config {
      ipv4 {
        address = "${each.value.ipv4_addr}/${each.value.ipv4_cidr}"
        gateway = each.value.ipv4_gateway
      }
      ipv6 {
        address = each.value.vmnet1_ipv6_addr
      }
    }
    ip_config {
      ipv4 {
        address = "dhcp"
      }
      ipv6 {
        address = each.value.vmnet2_ipv6_addr
      }
    }
  }
}

resource "talos_machine_configuration_apply" "fmra" {
  depends_on                  = [proxmox_virtual_environment_vm.fmra]
  for_each                    = local.fmra_k8s_nodes
  node                        = each.value.ipv4_addr
  client_configuration        = talos_machine_secrets.fmra.client_configuration
  machine_configuration_input = data.talos_machine_configuration.fmra[each.key].machine_configuration
  config_patches              = [
    file("machine_config.patch"),
    yamlencode({
      machine = {
        nodeLabels = {
          "topology.kubernetes.io/region" = local.region
          "topology.kubernetes.io/zone" = each.value.hypervisor
        }
      }
    }),
    yamlencode({
      cluster = {
        inlineManifests = [
        {
          name = "cilium"
          contents = data.helm_template.cilium.manifest
        },
        {
          name = "proxmox-csi-plugin"
          contents = data.helm_template.proxmox-csi-plugin.manifest
        },
        {
          name = "metrics-server"
          contents = data.helm_template.metrics-server.manifest
        },
        ]
      }
    })
  ]
}

resource "talos_machine_bootstrap" "fmra" {
  depends_on = [talos_machine_configuration_apply.fmra]
  node                 = local.fmra_first_node.ipv4_addr
  client_configuration = talos_machine_secrets.fmra.client_configuration
}

resource "proxmox_virtual_environment_role" "csi" {
  role_id = "csi"
  privileges = [
    "VM.Audit",
    "VM.Config.Disk",
    "Datastore.Allocate",
    "Datastore.AllocateSpace",
    "Datastore.Audit"
  ]
}

resource "proxmox_virtual_environment_user" "csi_fmra" {
  user_id = "csi_fmra@pve"
  acl {
    path      = "/"
    propagate = true
    role_id   = proxmox_virtual_environment_role.csi.role_id
  }
}

resource "proxmox_virtual_environment_user_token" "csi_fmra" {
  token_name            = "csi"
  user_id               = proxmox_virtual_environment_user.csi_fmra.user_id
  privileges_separation = false
}

resource "local_file" "talosconfig" {
  filename        = "talosconfig"
  content         = data.talos_client_configuration.fmra.talos_config
  file_permission = "0600"
}

resource "talos_cluster_kubeconfig" "fmra" {
  client_configuration = talos_machine_secrets.fmra.client_configuration
  node                 = local.fmra_first_node.ipv4_addr
}

resource "local_file" "kubeconfig" {
  filename        = "kubeconfig"
  content         = talos_cluster_kubeconfig.fmra.kubeconfig_raw
  file_permission = "0600"
}

resource "tls_private_key" "cilium" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "cilium" {
  private_key_pem  = tls_private_key.cilium.private_key_pem

  subject {
    common_name  = "Cilium CA (from TF)"
  }

  validity_period_hours = 24*365

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

data "helm_template" "cilium" {
  namespace    = "kube-system"
  name         = "cilium"
  repository   = "https://helm.cilium.io"
  chart        = "cilium"
  version      = "1.19.2"
  kube_version = local.fmra_kubernetes_version
  values = [ 
    <<-YAML
    autoDirectNodeRoutes: true
    cgroup:
      autoMount:
        enabled: false
    cgroup:
      hostRoot: /sys/fs/cgroup
    hubble:
      tls:
        auto:
          method: cronjob
    clustermesh:
      apiserver:
        tls:
          auto:
            method: cronjob
    k8sServiceHost: localhost
    k8sServicePort: 7445
    ipam:
      mode: cluster-pool
      operator:
        clusterPoolIPv4MaskSize: 24
        clusterPoolIPv4PodCIDRList: 10.44.0.0/16
        clusterPoolIPv6MaskSize: 120
        clusterPoolIPv6PodCIDRList: fd44::/112
    ipv4NativeRoutingCIDR: 10.44.0.0/16
    ipv6NativeRoutingCIDR: fd44::/112
    ipv6:
      enabled: true
    l2announcements:
      enabled: true
    kubeProxyReplacement: true
    routingMode: native
    securityContext:
      capabilities:
        ciliumAgent: [CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID]
        cleanCiliumState: [NET_ADMIN,SYS_ADMIN,SYS_RESOURCE]
    tls:
      ca:
        cert: ${base64encode(tls_self_signed_cert.cilium.cert_pem)}
        key: ${base64encode(tls_self_signed_cert.cilium.private_key_pem)}
    YAML
  ]
}

data "helm_template" "proxmox-csi-plugin" {
  namespace    = "kube-system"
  name         = "proxmox-csi-plugin"
  repository   = "oci://ghcr.io/sergelogvinov/charts"
  chart        = "proxmox-csi-plugin"
  version      = "0.5.6"
  values = [ 
    <<-YAML
    config:
      clusters:
        - url: "${local.proxmox_api_endpoint}"
          insecure: true
          token_id: "${proxmox_virtual_environment_user_token.csi_fmra.id}"
          token_secret: "${split("=", proxmox_virtual_environment_user_token.csi_fmra.value)[1]}"
          region: "${local.region}"
    storageClass:
      - name: local-zfs
        storage: local-zfs
        fstype: xfs
        annotations:
          storageclass.kubernetes.io/is-default-class: "true"
      - name: ceph
        storage: ceph
        fstype: xfs
    YAML
  ]
}

data "helm_template" "metrics-server" {
  namespace    = "kube-system"
  name         = "metrics-server"
  repository   = "https://kubernetes-sigs.github.io/metrics-server/"
  chart        = "metrics-server"
  version      = "3.13.0"
  values = [
    <<-YAML
    args:
      - --kubelet-insecure-tls
    YAML
  ]
}
