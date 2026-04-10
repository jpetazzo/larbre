resource "talos_image_factory_schematic" "_" {
  schematic = yamlencode(
    {
      customization = {
        systemExtensions = {
          officialExtensions = local.talos_extensions
        }
      }
    }
  )
}

data "talos_image_factory_urls" "_" {
  talos_version = local.talos_version
  schematic_id  = talos_image_factory_schematic._.id
  platform      = "nocloud"
  architecture  = "amd64"
}

resource "proxmox_virtual_environment_download_file" "talos_disk_image" {
  for_each                = toset(local.proxmox_nodes)
  node_name               = each.value
  content_type            = "iso"
  datastore_id            = "local"
  decompression_algorithm = "gz"
  overwrite               = false
  url                     = data.talos_image_factory_urls._.urls.disk_image
  file_name               = "talos-${local.talos_cluster_name}.img"
}
