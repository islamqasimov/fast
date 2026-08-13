#!/bin/bash
# ============================================================
# OSINT IOC Collector + Wazuh SIEM - Tam Avtomatik Deploy
# ============================================================
#
# Bu skript bunu edir:
#   1. Terraform ilə GCP-də 3 Ubuntu VM yaradır
#      (wazuh-manager, ioc-collector, linux-target)
#   2. Ansible inventory-ni avtomatik generasiya edir
#   3. Ansible ilə bütün stack-i konfiqurasiya edir:
#      - Wazuh Manager+Indexer+Dashboard (Docker)
#      - OSINT IOC Collector-u köçürüb ilk fetch-i işə salır
#      - Wazuh Agent-i Linux target-də quraşdırır
#      - IOC->Wazuh CDB inteqrasiyasını qurur + gündəlik cron
#
# ÖN ŞƏRTLƏR (bu skriptdən əvvəl edilməli):
#   - terraform.tfvars doldurulub (infra/terraform/)
#   - GCP-də Service Account + JSON key hazırdır
#   - SSH açar cütü yaradılıb (~/.ssh/gcp_wazuh_key)
#   - gcloud auth login edilib
#
# İstifadə: cd infra && ./deploy.sh
# ============================================================

set -e  # istənilən addım xəta versə, dərhal dayan

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/terraform"
ANSIBLE_DIR="$SCRIPT_DIR/ansible"

echo "════════════════════════════════════════════════════════"
echo "  OSINT IOC Collector + Wazuh SIEM - Deploy Başlayır"
echo "════════════════════════════════════════════════════════"

# --- Ön şərt yoxlamaları ---
if [ ! -f "$TERRAFORM_DIR/terraform.tfvars" ]; then
    echo "✗ XƏTA: terraform.tfvars tapılmadı."
    echo "  Əvvəlcə: cd infra/terraform && cp terraform.tfvars.example terraform.tfvars"
    echo "  Sonra öz məlumatlarınla doldur."
    exit 1
fi

if [ ! -f "$HOME/.ssh/gcp_wazuh_key" ]; then
    echo "✗ XƏTA: SSH açarı tapılmadı (~/.ssh/gcp_wazuh_key)"
    echo "  Yarat: ssh-keygen -t rsa -b 4096 -f ~/.ssh/gcp_wazuh_key -N \"\""
    exit 1
fi

command -v terraform >/dev/null 2>&1 || { echo "✗ terraform quraşdırılmayıb"; exit 1; }
command -v ansible-playbook >/dev/null 2>&1 || { echo "✗ ansible quraşdırılmayıb"; exit 1; }

echo "✓ Ön şərtlər OK"
echo ""

# --- ADDIM 1: Terraform ---
echo "════════════════════════════════════════════════════════"
echo "  ADDIM 1/3: Terraform - GCP-də VM-lərin yaradılması"
echo "════════════════════════════════════════════════════════"

cd "$TERRAFORM_DIR"
terraform init -input=false

echo ""
echo "📋 Terraform plan göstərilir - nə yaradılacağını yoxla:"
terraform plan -out=tfplan

echo ""
read -p "Yuxarıdakı planı təsdiqləyirsən? Davam etsin? (bəli/xeyr): " confirm
if [ "$confirm" != "bəli" ] && [ "$confirm" != "b" ] && [ "$confirm" != "yes" ] && [ "$confirm" != "y" ]; then
    echo "Dayandırıldı - heç nə yaradılmadı."
    exit 0
fi

terraform apply tfplan
echo "✓ VM-lər yaradıldı"
echo ""

# --- ADDIM 2: Ansible Inventory ---
echo "════════════════════════════════════════════════════════"
echo "  ADDIM 2/3: Ansible Inventory Generasiyası"
echo "════════════════════════════════════════════════════════"

cd "$ANSIBLE_DIR"
chmod +x generate_inventory.sh
./generate_inventory.sh

echo ""
echo "⏳ VM-lərin tam açılmasını gözləyirik (60 saniyə, cloud-init tamamlansın)..."
sleep 60

# --- ADDIM 3: Ansible ---
echo "════════════════════════════════════════════════════════"
echo "  ADDIM 3/3: Ansible - Wazuh + IOC Collector Konfiqurasiyası"
echo "════════════════════════════════════════════════════════"
echo "  (Bu addım 15-25 dəqiqə çəkə bilər - Docker image-lər yüklənir)"
echo ""

ansible-playbook site.yml

echo ""
echo "════════════════════════════════════════════════════════"
echo "  ✅ DEPLOY TAMAMLANDI"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Wazuh Dashboard:"
terraform -chdir="$TERRAFORM_DIR" output wazuh_dashboard_url
echo ""
echo "SSH əmrləri:"
terraform -chdir="$TERRAFORM_DIR" output ssh_commands
echo ""
echo "Qeyd: Dashboard-a ilk girişdə default istifadəçi/parol:"
echo "  İstifadəçi: admin"
echo "  Parol: /opt/wazuh-docker/single-node/config/wazuh_indexer/certs.yml"
echo "  qonşuluğunda .env faylında və ya Wazuh sənədlərində tapıla bilər"
echo "  (rəsmi default: admin/SecretPassword, ilk girişdə dəyişdirilməlidir)"
