#!/bin/bash
# ============================================================
# F.A.S.T. - IOC Yeniləmə Skripti
# ============================================================
# deploy.sh-in tam quraşdırma addımlarını təkrarlamadan,
# yalnız IOC-ları yenidən yığıb Wazuh-a push edir.
#
# İstifadə: ./refresh_iocs.sh
# Cron üçün nümunə (hər gün saat 03:00): 
#   0 3 * * * /path/to/osint-ioc-collector/refresh_iocs.sh >> /var/log/fast-refresh.log 2>&1
# ============================================================

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANAGER_CONTAINER="single-node-wazuh.manager-1"

echo "===== $(date -u +%Y-%m-%dT%H:%M:%SZ) - IOC yeniləmə başladı ====="

cd "$PROJECT_ROOT"
docker run --rm -v "$PROJECT_ROOT:/app" osint-ioc-collector \
    --fetch --export wazuh

docker cp "$PROJECT_ROOT/sample_output/ioc-ips" "${MANAGER_CONTAINER}:/var/ossec/etc/lists/ioc-ips"
docker restart "$MANAGER_CONTAINER" >/dev/null

echo "⏳ Restart-dan sonra sağlamlıq yoxlanılır (20 saniyə)..."
sleep 20

critical_errors=$(docker logs "$MANAGER_CONTAINER" --since 30s 2>&1 | grep -c "CRITICAL" || true)
proc_count=$(docker exec "$MANAGER_CONTAINER" ps aux 2>/dev/null | grep -cE "wazuh-authd|wazuh-analysisd|wazuh-remoted" || true)

if [ "$critical_errors" -eq 0 ] && [ "$proc_count" -ge 3 ]; then
    echo "✓ Manager sağlamdır"
else
    echo "⚠️  XƏBƏRDARLIQ: Manager restart-dan sonra sağlam görünmür."
    echo "   Diaqnostika: docker logs $MANAGER_CONTAINER | grep -i error"
fi

echo "===== $(date -u +%Y-%m-%dT%H:%M:%SZ) - IOC yeniləmə tamamlandı ====="
