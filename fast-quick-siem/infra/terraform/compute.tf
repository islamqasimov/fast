############################################
# VM 1: Wazuh Manager + Indexer + Dashboard
############################################

resource "google_compute_instance" "wazuh_manager" {
  name         = "wazuh-manager"
  machine_type = var.wazuh_manager_machine_type
  zone         = var.zone
  tags         = ["wazuh-lab"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = var.wazuh_manager_disk_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.wazuh_subnet.id
    access_config {} # public IP təyin edir
  }

  metadata = {
    ssh-keys  = "${var.ssh_username}:${file(var.ssh_public_key_path)}"
    user-data = file("${path.module}/../cloud-init/base-setup.yml")
  }
}

############################################
# VM 2: OSINT IOC Collector
############################################

resource "google_compute_instance" "ioc_collector" {
  name         = "ioc-collector"
  machine_type = var.ioc_collector_machine_type
  zone         = var.zone
  tags         = ["wazuh-lab"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = var.ioc_collector_disk_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.wazuh_subnet.id
    access_config {}
  }

  metadata = {
    ssh-keys  = "${var.ssh_username}:${file(var.ssh_public_key_path)}"
    user-data = file("${path.module}/../cloud-init/base-setup.yml")
  }
}

############################################
# VM 3: Linux Target (Wazuh Agent quraşdırılacaq)
# Yalnız var.deploy_linux_target = true olduqda yaradılır
############################################

resource "google_compute_instance" "linux_target" {
  count        = var.deploy_linux_target ? 1 : 0
  name         = "linux-target"
  machine_type = var.linux_target_machine_type
  zone         = var.zone
  tags         = ["wazuh-lab"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = var.linux_target_disk_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.wazuh_subnet.id
    access_config {}
  }

  metadata = {
    ssh-keys  = "${var.ssh_username}:${file(var.ssh_public_key_path)}"
    user-data = file("${path.module}/../cloud-init/base-setup.yml")
  }
}

