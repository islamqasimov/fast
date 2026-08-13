#!/bin/bash
# ============================================================
# F.A.S.T. - Linux Wazuh Agent Avtomatik Quraşdırma
# ============================================================
#
# Bu skript Linux host maşınında Wazuh Agent-i endirir,
# quraşdırır, Manager-ə (cloud VM-ə) qoşulacaq şəkildə
# konfiqurasiya edir və servisi başladır.
#
# Dəstəklənən distro-lar:
#   - Ubuntu / Debian (apt)
#   - CentOS / RHEL / Fedora (yum/dnf)
#
# İSTİFADƏ:
#   sudo ./install-wazuh-agent.sh --ip <MANAGER_IP>
#   sudo ./install-wazuh-agent.sh --ip 100.87.195.65
#
# İstəyə bağlı:
#   sudo ./install-wazuh-agent.sh --ip 100.87.195.65 --name "my-server"
# ============================================================

set -e

WAZUH_VERSION="4.9.0"
MANAGER_IP=""
AGENT_NAME="$(hostname)"

# --- Rəngli çıxış ---
GREEN="\033[0;32m"
CYAN="\033[0;36m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m"

step()    { echo -e "\n${CYAN}==> $1${NC}"; }
success() { echo -e "${GREEN}[OK] $1${NC}"; }
warn()    { echo -e "${YELLOW}[!]  $1${NC}"; }
fail()    { echo -e "${RED}[XETA] $1${NC}"; exit 1; }

# --- Parametrlərin oxunması ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --ip|-i)
            MANAGER_IP="$2"
            shift 2
            ;;
        --name|-n)
            AGENT_NAME="$2"
            shift 2
            ;;
        -h|--help)
            echo "İstifadə: sudo $0 --ip <MANAGER_IP> [--name <AGENT_ADI>]"
            echo ""
            echo "  --ip   <IP>    Wazuh Manager-in IP-si (məcburi)"
            echo "  --name <AD>    Agent-ə verilən ad (default: hostname)"
            echo ""
            echo "Nümunə:"
            echo "  sudo $0 --ip 100.87.195.65"
            echo "  sudo $0 --ip 100.87.195.65 --name elmir-ubuntu"
            exit 0
            ;;
        *)
            fail "Naməlum parametr: $1  (bax: $0 --help)"
            ;;
    esac
done

# --- Məcburi parametr yoxlaması ---
if [ -z "$MANAGER_IP" ]; then
    echo -e "${RED}Xəta: --ip parametri mütləqdir.${NC}"
    echo ""
    echo "İstifadə: sudo $0 --ip <MANAGER_IP>"
    echo "Nümunə:   sudo $0 --ip 100.87.195.65"
    exit 1
fi

# --- Root yoxlaması ---
if [ "$EUID" -ne 0 ]; then
    fail "Bu skript root hüququ tələb edir. 'sudo ./install-wazuh-agent.sh ...' ilə işlət."
fi

echo ""
echo "============================================================"
echo -e "  ${CYAN}F.A.S.T. - Linux Wazuh Agent Quraşdırma${NC}"
echo "============================================================"
echo "Manager IP : $MANAGER_IP"
echo "Agent Adı  : $AGENT_NAME"
echo "Versiya    : $WAZUH_VERSION"

# --- Paket meneceri aşkarlama ---
step "Paket meneceri aşkarlanır..."
if command -v apt-get >/dev/null 2>&1; then
    PKG_MANAGER="apt"
    success "apt aşkarlandı (Ubuntu/Debian)"
elif command -v dnf >/dev/null 2>&1; then
    PKG_MANAGER="dnf"
    success "dnf aşkarlandı (Fedora/RHEL 8+)"
elif command -v yum >/dev/null 2>&1; then
    PKG_MANAGER="yum"
    success "yum aşkarlandı (CentOS/RHEL)"
else
    fail "Dəstəklənən paket meneceri tapılmadı (apt/dnf/yum lazımdır)"
fi

# --- Manager IP-nin əlçatan olduğunu yoxla ---
step "Manager-in əlçatanlığı yoxlanılır ($MANAGER_IP)..."
ALL_PORTS_OK=true
for port in 1514 1515; do
    if timeout 5 bash -c ">/dev/tcp/$MANAGER_IP/$port" 2>/dev/null; then
        success "Port $port əlçatandır"
    else
        warn "Port $port əlçatan deyil"
        ALL_PORTS_OK=false
    fi
done

if [ "$ALL_PORTS_OK" = false ]; then
    echo ""
    warn "Bəzi portlar əlçatan deyil. Mümkün səbəblər:"
    echo "  - Manager (VM) hələ tam açılmayıb (deploy.sh bitməyib)"
    echo "  - VM-in firewall/security group qaydası 1514/1515 portlarını bağlayıb"
    echo "  - Tailscale istifadə edirsənsə, hər iki tərəf qoşulu deyil"
    echo ""
    read -rp "Yenə də davam etmək istəyirsən? (b/x): " yn
    if [[ "$yn" != "b" && "$yn" != "B" ]]; then
        echo "Dayandırıldı."
        exit 0
    fi
fi

# --- Mövcud agentin dayandırılması ---
if systemctl is-active --quiet wazuh-agent 2>/dev/null; then
    step "Mövcud Wazuh Agent tapıldı, dayandırılır..."
    systemctl stop wazuh-agent
    success "Köhnə agent dayandırıldı"
fi

# --- Wazuh repo əlavə etmə + quraşdırma ---
step "Wazuh Agent quraşdırılır ($PKG_MANAGER)..."

if [ "$PKG_MANAGER" = "apt" ]; then
    # Wazuh GPG açarı + repo
    if ! apt-get install -y gnupg curl 2>/dev/null; then
        apt-get update -qq && apt-get install -y gnupg curl
    fi

    curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --dearmor -o /usr/share/keyrings/wazuh.gpg
    echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" \
        > /etc/apt/sources.list.d/wazuh.list

    apt-get update -qq
    WAZUH_MANAGER="$MANAGER_IP" WAZUH_AGENT_NAME="$AGENT_NAME" \
        apt-get install -y "wazuh-agent=$WAZUH_VERSION-1"

elif [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
    # Wazuh repo faylı
    cat > /etc/yum.repos.d/wazuh.repo << EOF
[wazuh]
gpgcheck=1
gpgkey=https://packages.wazuh.com/key/GPG-KEY-WAZUH
enabled=1
name=EL - Wazuh
baseurl=https://packages.wazuh.com/4.x/yum/
protect=1
EOF

    WAZUH_MANAGER="$MANAGER_IP" WAZUH_AGENT_NAME="$AGENT_NAME" \
        $PKG_MANAGER install -y "wazuh-agent-$WAZUH_VERSION-1"
fi

success "Wazuh Agent quraşdırıldı"

# --- ossec.conf-da Manager IP-sini təyin et (mühit dəyişənindən düşmədiyi halda) ---
OSSEC_CONF="/var/ossec/etc/ossec.conf"
if [ -f "$OSSEC_CONF" ]; then
    # Manager adresinin doğru yazıldığını yoxla, lazım gəlsə əl ilə düzəlt
    if ! grep -q "<address>$MANAGER_IP</address>" "$OSSEC_CONF"; then
        step "Manager IP-si ossec.conf-a yazılır..."
        sed -i "s|<address>.*</address>|<address>$MANAGER_IP</address>|g" "$OSSEC_CONF"
        success "ossec.conf yeniləndi"
    fi
fi

# --- Servisi başlat ---
step "Wazuh Agent servisi başladılır..."
systemctl daemon-reload
systemctl enable wazuh-agent
systemctl start wazuh-agent
sleep 5

STATUS=$(systemctl is-active wazuh-agent)
if [ "$STATUS" = "active" ]; then
    success "Servis işləyir (Status: $STATUS)"
else
    warn "Servisin statusu: $STATUS — logları yoxla:"
    echo "  journalctl -u wazuh-agent -n 20"
fi

# --- Son logları göstər (qoşulma vəziyyəti üçün) ---
step "Son log qeydləri (10 saniyə gözlənilir)..."
sleep 10
LOG="/var/ossec/logs/ossec.log"
if [ -f "$LOG" ]; then
    grep "wazuh-agentd" "$LOG" | tail -8
else
    warn "Log faylı tapılmadı: $LOG"
fi

echo ""
echo "============================================================"
echo -e "  ${GREEN}TAMAMLANDI${NC}"
echo "============================================================"
echo ""
echo "Qoşulmanı Manager tərəfdə (VM-də) təsdiqlə:"
echo "  docker exec single-node-wazuh.manager-1 /var/ossec/bin/agent_control -l"
echo ""
echo "Yaxud Dashboard-da: Agents bölməsi → '$AGENT_NAME' axtar"
echo ""
echo "Əgər 'SSL error, Connection refused' görürsənsə:"
echo "  - Manager-in sağlam açıldığını yoxla"
echo "  - docs/DEPLOYMENT_GUIDE.md → 'Problemlərin Həlli' bölməsinə bax"
