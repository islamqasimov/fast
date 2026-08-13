#!/bin/bash
# Terraform output-undan IP-ləri oxuyub inventory.ini-ni avtomatik yaradır.
# İstifadə: cd infra/ansible && ./generate_inventory.sh

set -e

TERRAFORM_DIR="../terraform"
OUTPUT_FILE="inventory.ini"

echo "📡 Terraform output oxunur..."

WAZUH_IP=$(terraform -chdir="$TERRAFORM_DIR" output -raw wazuh_manager_public_ip)
IOC_IP=$(terraform -chdir="$TERRAFORM_DIR" output -raw ioc_collector_public_ip)
LINUX_IP=$(terraform -chdir="$TERRAFORM_DIR" output -raw linux_target_public_ip)

{
  echo "# AVTOMATIK YARADILIB - əl ilə redaktə etmə (generate_inventory.sh çağır)"
  echo ""
  echo "[wazuh_manager]"
  echo "wazuh-manager ansible_host=${WAZUH_IP}"
  echo ""
  echo "[ioc_collector]"
  echo "ioc-collector ansible_host=${IOC_IP}"
  echo ""
  echo "[linux_target]"
  if [ -n "$LINUX_IP" ]; then
    echo "linux-target ansible_host=${LINUX_IP}"
  fi
  echo ""
  echo "[all:vars]"
  echo "ansible_user=wazuhadmin"
  echo "ansible_ssh_private_key_file=~/.ssh/gcp_wazuh_key"
  echo "ansible_python_interpreter=/usr/bin/python3"
} > "$OUTPUT_FILE"

echo "✓ inventory.ini yaradıldı:"
echo "  wazuh-manager -> ${WAZUH_IP}"
echo "  ioc-collector -> ${IOC_IP}"

if [ -n "$LINUX_IP" ]; then
  echo "  linux-target  -> ${LINUX_IP}"
else
  echo "  linux-target  -> (deploy edilməyib)"
fi
