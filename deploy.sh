#!/bin/bash
# ============================================================
# F.A.S.T. - OSINT Threat Aggregation + Wazuh SIEM
# Tək-Skriptli Sürətli Deployment
# ============================================================
#
# Bu skript bunu edir:
#   1. Rəsmi Wazuh Docker stack-ini (Manager+Indexer+Dashboard) endirir
#      (ilk dəfə - sonrakı işlətmələrdə bu addım keçilir)
#   2. Sertifikatları generasiya edir (ilk dəfə)
#   3. Wazuh stack-ini TAM DEFAULT konfiqurasiya ilə işə salır
#      (heç bir bind-mount yoxdur - bu, Wazuh-un öz ilkin fayl
#      strukturunu yaratma prosesini pozmasın deyə qəsdən belədir)
#   4. Manager-in sağlam açıldığını yoxlayır (authd/analysisd/remoted)
#   5. Custom detection qaydasını `docker cp` ilə köçürür (Manager
#      artıq sağlam açıldıqdan SONRA - bu, kritik ardıcıllıqdır)
#   6. IOC Collector image-ni tikir və ilk yığımı işə salır
#   7. CDB list-i `docker cp` ilə köçürüb Manager-i restart edir
#   8. Hər restart-dan sonra yenidən sağlamlıq yoxlanışı edir
#
# QEYD: Əvvəlki versiyada docker-compose.override.yml ilə
# /var/ossec/etc/lists qovluğunu bütövlükdə bind-mount etmək
# Wazuh-un `ar.conf` kimi ilkin fayllarını yarada bilməməsinə səbəb
# olurdu (analysisd "Configuration error" ilə çıxırdı, authd heç
# başlamırdı). Bu versiya yalnız `docker cp` istifadə edir - Manager
# tam sağlam işə düşdükdən sonra.
#
# TƏLƏBLƏR: Docker + Docker Compose plugin quraşdırılmış olmalıdır
#
# İSTİFADƏ: ./deploy.sh [--ip <MANAGER_IP>]
#   --ip <IP>   Manager-in IP-sini əl ilə təyin et (agent-lərə göstərmək
#               üçün). Verilməsə, avtomatik aşkarlanır: əvvəlcə Tailscale
#               IP-si, tapılmasa public IP, o da tapılmasa lokal IP.
# YENİLƏMƏ ÜÇÜN (yalnız IOC-ları təzələmək): ./refresh_iocs.sh
# ============================================================

set -e

# --- Parametrlərin oxunması ---
MANAGER_IP_OVERRIDE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --ip|-i)
            MANAGER_IP_OVERRIDE="$2"
            shift 2
            ;;
        -h|--help)
            echo "İstifadə: ./deploy.sh [--ip <MANAGER_IP>]"
            echo ""
            echo "  --ip <IP>   Manager-in IP-sini əl ilə təyin et."
            echo "              Verilməsə, avtomatik aşkarlanır."
            exit 0
            ;;
        *)
            echo "✗ Naməlum parametr: $1 (bax: ./deploy.sh --help)"
            exit 1
            ;;
    esac
done

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WAZUH_DIR="$PROJECT_ROOT/wazuh-docker"
WAZUH_VERSION="v4.9.0"
MANAGER_CONTAINER="single-node-wazuh.manager-1"
HEALTH_CHECK_TIMEOUT=180   # saniyə
HEALTH_CHECK_INTERVAL=10   # saniyə

echo "════════════════════════════════════════════════════════"
echo "  F.A.S.T. - Deployment Başlayır"
echo "════════════════════════════════════════════════════════"

# --- Ön şərt yoxlamaları ---
command -v docker >/dev/null 2>&1 || { echo "✗ Docker quraşdırılmayıb. Quraşdır: https://docs.docker.com/engine/install/"; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "✗ Docker Compose plugin tapılmadı."; exit 1; }
command -v git >/dev/null 2>&1 || { echo "✗ Git quraşdırılmayıb."; exit 1; }

echo "✓ Docker, Docker Compose, Git mövcuddur"
echo ""

# --- Köməkçi funksiya: Manager-ə qoşulmaq üçün istifadə oluna biləcək IP-ni tapır ---
# Sıra: 1) --ip ilə verilən dəyər, 2) Tailscale IP (varsa), 3) public IP, 4) lokal IP
_is_valid_ipv4() {
    local ip="$1"
    [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    local IFS='.'
    local -a octets=($ip)
    for octet in "${octets[@]}"; do
        [ "$octet" -le 255 ] || return 1
    done
    return 0
}

detect_manager_ip() {
    if [ -n "$MANAGER_IP_OVERRIDE" ]; then
        echo "$MANAGER_IP_OVERRIDE"
        return
    fi

    if command -v tailscale >/dev/null 2>&1; then
        local ts_ip
        ts_ip=$(tailscale ip -4 2>/dev/null | head -1)
        if _is_valid_ipv4 "$ts_ip"; then
            echo "$ts_ip"
            return
        fi
    fi

    local pub_ip
    pub_ip=$(curl -sf --max-time 5 https://ifconfig.me 2>/dev/null)
    if _is_valid_ipv4 "$pub_ip"; then
        echo "$pub_ip"
        return
    fi

    local local_ip
    local_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    if _is_valid_ipv4 "$local_ip"; then
        echo "$local_ip"
        return
    fi

    # Heç biri tapılmadı - boş qaytarır, çağıran tərəf bunu idarə edir
    echo ""
}

# --- Köməkçi funksiya: Manager-in sağlam olduğunu yoxlayır ---
# Sağlam = wazuh-authd, wazuh-analysisd, wazuh-remoted proseslərinin
# hamısı işləyir VƏ loglarda CRITICAL xəta yoxdur.
wait_for_manager_healthy() {
    local elapsed=0
    echo "🔍 Manager-in sağlamlığı yoxlanılır..."

    while [ "$elapsed" -lt "$HEALTH_CHECK_TIMEOUT" ]; do
        local critical_errors
        critical_errors=$(docker logs "$MANAGER_CONTAINER" 2>&1 | grep -c "CRITICAL" || true)

        local proc_count
        proc_count=$(docker exec "$MANAGER_CONTAINER" ps aux 2>/dev/null | grep -cE "wazuh-authd|wazuh-analysisd|wazuh-remoted" || true)

        if [ "$critical_errors" -eq 0 ] && [ "$proc_count" -ge 3 ]; then
            echo "✓ Manager sağlamdır (authd, analysisd, remoted işləyir, xəta yoxdur)"
            return 0
        fi

        sleep "$HEALTH_CHECK_INTERVAL"
        elapsed=$((elapsed + HEALTH_CHECK_INTERVAL))
        echo "  ... gözlənilir (${elapsed}s/${HEALTH_CHECK_TIMEOUT}s)"
    done

    echo "✗ XƏTA: Manager ${HEALTH_CHECK_TIMEOUT} saniyə ərzində sağlam vəziyyətə gəlmədi."
    echo "  Diaqnostika üçün: docker logs $MANAGER_CONTAINER | grep -i error"
    return 1
}

# --- ADDIM 1: Wazuh Docker Repo ---
if [ ! -d "$WAZUH_DIR" ]; then
    echo "📥 Wazuh Docker stack-i endirilir ($WAZUH_VERSION)..."
    git clone --branch "$WAZUH_VERSION" --depth 1 https://github.com/wazuh/wazuh-docker.git "$WAZUH_DIR"
else
    echo "✓ Wazuh Docker stack-i artıq mövcuddur ($WAZUH_DIR)"
fi

cd "$WAZUH_DIR/single-node"

# --- ADDIM 2: Sertifikatlar ---
if [ ! -d "config/wazuh_indexer_ssl_certs" ] || [ -z "$(ls -A config/wazuh_indexer_ssl_certs 2>/dev/null)" ]; then
    echo ""
    echo "🔐 SSL sertifikatları generasiya edilir..."
    docker compose -f generate-indexer-certs.yml run --rm generator
else
    echo "✓ Sertifikatlar artıq mövcuddur"
fi

# Köhnə override faylı qalıbsa (əvvəlki versiyadan), sil - bind-mount
# problemlərinin qarşısını almaq üçün. Bax: fayl başındakı QEYD.
if [ -f "./docker-compose.override.yml" ]; then
    echo "⚠️  Köhnə docker-compose.override.yml tapıldı, silinir (bind-mount problemi yaradırdı)..."
    rm -f ./docker-compose.override.yml
fi

# --- ADDIM 3: Wazuh Stack-in TAM DEFAULT Konfiqurasiya ilə İşə Salınması ---
echo ""
echo "🚀 Wazuh Manager + Indexer + Dashboard işə salınır (default konfiqurasiya)..."
docker compose up -d

echo ""
echo "⏳ Konteynerlərin başlaması gözlənilir (30 saniyə)..."
sleep 30

# --- ADDIM 4: Sağlamlıq Yoxlanışı (Rules/List köçürülməzdən ƏVVƏL) ---
if ! wait_for_manager_healthy; then
    echo "✗ Deployment dayandırıldı - Manager sağlam açılmadı."
    exit 1
fi

# --- ADDIM 5: Custom Detection Qaydasının docker cp ilə Köçürülməsi ---
echo ""
echo "🔗 OSINT IOC Collector detection qaydası tətbiq edilir..."
docker cp "$PROJECT_ROOT/docker/rules/local_rules.xml" "${MANAGER_CONTAINER}:/var/ossec/etc/rules/local_rules.xml"
docker restart "$MANAGER_CONTAINER" >/dev/null

echo "⏳ Restart-dan sonra sağlamlıq yenidən yoxlanılır..."
sleep 20
if ! wait_for_manager_healthy; then
    echo "✗ Deployment dayandırıldı - custom qaydadan sonra Manager sağlam açılmadı."
    exit 1
fi

# --- ADDIM 6: IOC Collector - Build + İlk Yığım ---
echo ""
echo "════════════════════════════════════════════════════════"
echo "  OSINT IOC Collector - İlk Yığım"
echo "════════════════════════════════════════════════════════"
cd "$PROJECT_ROOT"

echo "🔨 IOC Collector image-i tikilir..."
docker build -t osint-ioc-collector -f docker/ioc-collector.Dockerfile .

echo ""
echo "📡 Feed-lərdən yığılır, normallaşdırılır, Wazuh CDB export edilir..."
docker run --rm -v "$PROJECT_ROOT:/app" osint-ioc-collector \
    --init-db --fetch --export wazuh

# --- ADDIM 7: CDB List-in docker cp ilə Köçürülməsi ---
echo ""
echo "🔄 CDB list Wazuh Manager-ə köçürülür və tətbiq edilir..."
docker cp "$PROJECT_ROOT/sample_output/ioc-ips" "${MANAGER_CONTAINER}:/var/ossec/etc/lists/ioc-ips"
docker restart "$MANAGER_CONTAINER" >/dev/null

echo "⏳ Son restart-dan sonra sağlamlıq yoxlanılır..."
sleep 20
if ! wait_for_manager_healthy; then
    echo "✗ XƏBƏRDARLIQ: CDB list köçürüldükdən sonra Manager sağlam görünmür."
    echo "  Diaqnostika: docker logs $MANAGER_CONTAINER | grep -i error"
    echo "  (Dashboard yenə də işləyə bilər, amma detection qaydalarını yoxla)"
fi

echo ""
echo "════════════════════════════════════════════════════════"
echo "  ✅ DEPLOYMENT TAMAMLANDI"
echo "════════════════════════════════════════════════════════"

DETECTED_IP=$(detect_manager_ip)

echo ""
echo "Wazuh Dashboard:  https://${DETECTED_IP:-localhost}"
echo "  İstifadəçi: admin"
echo "  Parol:      SecretPassword (ilk girişdə dəyişdir!)"
echo ""

if [ -n "$DETECTED_IP" ]; then
    echo "────────────────────────────────────────────────────────"
    echo "  Agent Qoşulması Üçün Manager IP: $DETECTED_IP"
    echo "────────────────────────────────────────────────────────"
    echo ""
    echo "Windows host-dan qoşmaq üçün (PowerShell, Administrator):"
    echo "  cd windows"
    echo "  .\\install-wazuh-agent.ps1 -ManagerIP \"$DETECTED_IP\""
    echo ""
    echo "Linux hədəfdən qoşmaq üçün:"
    echo "  curl -so wazuh-agent.deb https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.9.0-1_amd64.deb"
    echo "  sudo WAZUH_MANAGER='$DETECTED_IP' dpkg -i ./wazuh-agent.deb"
    echo "  sudo systemctl enable --now wazuh-agent"
    echo ""
else
    echo "⚠️  Manager IP avtomatik aşkarlana bilmədi."
    echo "   Növbəti dəfə əl ilə göstər: ./deploy.sh --ip <IP_ADDRESS>"
    echo ""
fi

echo "IOC-ları yeniləmək üçün: ./refresh_iocs.sh"
echo "Stack-i dayandırmaq üçün: cd wazuh-docker/single-node && docker compose down"
