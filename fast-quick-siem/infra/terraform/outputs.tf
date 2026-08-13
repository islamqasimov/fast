output "wazuh_manager_public_ip" {
  description = "Wazuh Manager VM-inin public IP-si (Dashboard buradan açılacaq)"
  value       = google_compute_instance.wazuh_manager.network_interface[0].access_config[0].nat_ip
}

output "ioc_collector_public_ip" {
  description = "OSINT IOC Collector VM-inin public IP-si"
  value       = google_compute_instance.ioc_collector.network_interface[0].access_config[0].nat_ip
}

output "linux_target_public_ip" {
  description = "Linux target VM-inin public IP-si (deploy edilməyibsə boş string)"
  value       = var.deploy_linux_target ? google_compute_instance.linux_target[0].network_interface[0].access_config[0].nat_ip : ""
}

output "wazuh_dashboard_url" {
  description = "Wazuh Dashboard-a giriş linki"
  value       = "https://${google_compute_instance.wazuh_manager.network_interface[0].access_config[0].nat_ip}"
}

output "ssh_commands" {
  description = "VM-lərə SSH ilə qoşulmaq üçün əmrlər (yalnız deploy edilənlər göstərilir)"
  value = merge(
    {
      wazuh_manager = "ssh -i ~/.ssh/gcp_wazuh_key ${var.ssh_username}@${google_compute_instance.wazuh_manager.network_interface[0].access_config[0].nat_ip}"
      ioc_collector = "ssh -i ~/.ssh/gcp_wazuh_key ${var.ssh_username}@${google_compute_instance.ioc_collector.network_interface[0].access_config[0].nat_ip}"
    },
    var.deploy_linux_target ? {
      linux_target = "ssh -i ~/.ssh/gcp_wazuh_key ${var.ssh_username}@${google_compute_instance.linux_target[0].network_interface[0].access_config[0].nat_ip}"
    } : {}
  )
}
