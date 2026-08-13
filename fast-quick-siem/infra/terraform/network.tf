############################################
# VPC Şəbəkəsi
############################################

resource "google_compute_network" "wazuh_vpc" {
  name                    = "wazuh-lab-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "wazuh_subnet" {
  name          = "wazuh-lab-subnet"
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.wazuh_vpc.id
}

############################################
# Firewall Qaydaları
#
# Yalnız lazım olan portlar açıqdır, yalnız sənin IP-ndən:
# - 22   (SSH)
# - 443  (Wazuh Dashboard)
# - 1514 (Agent data)          -> Linux Wazuh agent buradan qoşulacaq
# - 1515 (Agent registration)
############################################

resource "google_compute_firewall" "allow_ssh" {
  name    = "wazuh-lab-allow-ssh"
  network = google_compute_network.wazuh_vpc.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = [var.my_public_ip]
  target_tags   = ["wazuh-lab"]
}

resource "google_compute_firewall" "allow_dashboard" {
  name    = "wazuh-lab-allow-dashboard"
  network = google_compute_network.wazuh_vpc.id

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = [var.my_public_ip]
  target_tags   = ["wazuh-lab"]
}

resource "google_compute_firewall" "allow_wazuh_agent" {
  name    = "wazuh-lab-allow-agent"
  network = google_compute_network.wazuh_vpc.id

  allow {
    protocol = "tcp"
    ports    = ["1514", "1515"]
  }

  source_ranges = [var.my_public_ip]
  target_tags   = ["wazuh-lab"]
}

# Daxili VPC trafiki - VM-lər öz aralarında sərbəst danışsın
resource "google_compute_firewall" "allow_internal" {
  name    = "wazuh-lab-allow-internal"
  network = google_compute_network.wazuh_vpc.id

  allow {
    protocol = "all"
  }

  source_ranges = [var.subnet_cidr]
  target_tags   = ["wazuh-lab"]
}
