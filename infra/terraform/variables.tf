############################################
# GCP AUTHENTICATION
############################################

variable "project_id" {
  description = "GCP Project ID (Console -> Project Info)"
  type        = string
}

variable "region" {
  description = "GCP region (məs: us-central1)"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone (məs: us-central1-a)"
  type        = string
  default     = "us-central1-a"
}

variable "credentials_file" {
  description = "Service Account JSON key faylının lokal yolu"
  type        = string
  default     = "~/.gcp/wazuh-lab-key.json"
}

############################################
# SSH ACCESS
############################################

variable "ssh_username" {
  description = "VM-lərə SSH ilə giriş üçün istifadəçi adı"
  type        = string
  default     = "wazuhadmin"
}

variable "ssh_public_key_path" {
  description = "VM-lərə giriş üçün SSH public key faylının yolu"
  type        = string
  default     = "~/.ssh/gcp_wazuh_key.pub"
}

# Sənin evindəki/işlədiyin yerin public IP-si.
# Wazuh Manager-in 1514/1515 (agent) və 443 (dashboard) portlarına
# YALNIZ bu IP-dən giriş icazəsi veriləcək (təhlükəsizlik üçün).
# Öyrənmək üçün: https://ifconfig.me
variable "my_public_ip" {
  description = "Sənin evindəki/işlədiyin yerin public IP-si (CIDR formatında, məs: 1.2.3.4/32)"
  type        = string
}

############################################
# COMPUTE MACHINE TYPES
#
# Qeyd: GCP Always Free yalnız 1x e2-micro (1 vCPU/1GB) verir - bu,
# Wazuh üçün kifayət etmir. Aşağıdakı ölçülər $300/90-gün kreditlə
# işləmək üçün nəzərdə tutulub. Krediti qorumaq üçün:
#   - İstifadə etmədiyin vaxt VM-ləri STOP et (terraform ilə yox,
#     `gcloud compute instances stop` ilə - disk saxlanılır, pul az gedir)
#   - Budget Alert mütləq qur (bax: infra/docs/cost-control.md)
############################################

variable "wazuh_manager_machine_type" {
  description = "Wazuh Manager+Indexer+Dashboard üçün maşın tipi"
  type        = string
  default     = "e2-standard-4" # 4 vCPU, 16GB RAM
}

variable "ioc_collector_machine_type" {
  description = "OSINT IOC Collector üçün maşın tipi"
  type        = string
  default     = "e2-small" # 2 vCPU, 2GB RAM
}

variable "linux_target_machine_type" {
  description = "Linux target (Wazuh Agent) üçün maşın tipi"
  type        = string
  default     = "e2-medium" # 2 vCPU, 4GB RAM
}

############################################
# DISK SIZES
############################################

variable "wazuh_manager_disk_gb" {
  description = "Wazuh Manager boot disk ölçüsü (GB)"
  type        = number
  default     = 100
}

############################################
# TARGET VM SEÇİMİ
############################################

variable "deploy_linux_target" {
  description = "Ubuntu Linux target VM-i yaradılsınmı?"
  type        = bool
  default     = true
}

variable "ioc_collector_disk_gb" {
  description = "IOC Collector boot disk ölçüsü (GB)"
  type        = number
  default     = 30
}

variable "linux_target_disk_gb" {
  description = "Linux target boot disk ölçüsü (GB)"
  type        = number
  default     = 30
}

############################################
# NETWORK
############################################

variable "subnet_cidr" {
  description = "Subnet üçün CIDR blok"
  type        = string
  default     = "10.10.0.0/24"
}
