output "talosconfig" {
  value = data.talos_client_configuration._.talos_config
}

output "kubeconfig" {
  value         = talos_cluster_kubeconfig._.kubeconfig_raw
}
