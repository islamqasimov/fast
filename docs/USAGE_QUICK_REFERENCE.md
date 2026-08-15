# F.A.S.T. — İstifadə Qaydası

**Arxitektura:** Wazuh SIEM cloud Ubuntu VM-də işləyir. Sənin host
maşının (Windows) Wazuh Agent ilə ona qoşulur.

## Bir Dəfəlik Quraşdırma

### 1. Cloud Ubuntu VM (GCP, AWS, yaxud istənilən provider)

VM-də (SSH ilə qoşulub):

```bash
# Docker quraşdır (Ubuntu 22.04)
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
# (yenidən giriş et ki, qrup dəyişikliyi tətbiq olunsun)

# Layihəni endir
git clone <bu-repo-url> fast-siem
cd fast-siem
chmod +x deploy.sh refresh_iocs.sh
```

### 2. Windows Host — WSL Quraşdırma (agent üçün lazım deyil, sadəcə
Tailscale istifadə edəcəksənsə əlverişlidir)

Əgər Tailscale istifadə edəcəksənsə (tövsiyə olunur), aşağıdakı
"Tailscale" bölməsinə bax.

## Hər Dəfə İstifadə

### Tam SIEM mühitini qaldırmaq (VM-də, yalnız ilk dəfə)

```bash
cd ~/fast-siem
./deploy.sh
```

~5-10 dəqiqə çəkir. Sonda Dashboard linki (VM-in IP-si ilə) göstərilir.

### Dashboard-a giriş

Brauzerdə: `https://<VM_PUBLIC_IP>` (VM-in IP-sini `curl ifconfig.me`
ilə VM-də tapa bilərsən)

- İstifadəçi: `admin`
- Parol: `SecretPassword` (ilk dəfə dəyiş)
- "Not secure" xəbərdarlığında: Advanced → Proceed

### Windows Host-u Agent Kimi Qoşmaq

**PowerShell-i Administrator kimi aç**, layihə qovluğunda:

```powershell
cd windows
.\install-wazuh-agent.ps1 -ManagerIP "<VM_IP>"
```

`<VM_IP>` yerinə VM-in public IP-sini (yaxud Tailscale istifadə
edirsənsə, VM-in Tailscale IP-sini) yaz. Skript hər şeyi (endirmə,
quraşdırma, servis başlatma, port yoxlanışı) avtomatik edir.

### Qoşulmanı Yoxlamaq

VM-də:
```bash
docker exec single-node-wazuh.manager-1 /var/ossec/bin/agent_control -l
```

Host maşının adı **Active** statusda görünməlidir.

### IOC-ları yeniləmək (VM-də, mühit artıq ayaqdadır)

```bash
cd ~/fast-siem
./refresh_iocs.sh
```

### Mühiti dayandırmaq (VM-də)

```bash
cd ~/fast-siem/wazuh-docker/single-node
docker compose down
```

### Yenidən başlatmaq (VM-də)

```bash
cd ~/fast-siem/wazuh-docker/single-node
docker compose up -d
```

### Tam silmək (VM-də)

```bash
cd ~/fast-siem/wazuh-docker/single-node
docker compose down -v
cd ~/fast-siem
rm -rf wazuh-docker
```

## Tailscale (Tövsiyə Olunur — Portları İnternetə Açmadan Qoşulmaq)

Əgər VM-in Wazuh portlarını (1514/1515) birbaşa internetə açmaq
istəmirsənsə:

**VM-də:**
```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
tailscale ip -4    # VM-in Tailscale IP-sini göstərir
```

**Windows host-da:**
1. https://tailscale.com/download/windows — quraşdır
2. Tray ikonuna bas → eyni hesabla giriş et
3. Tray ikonu → "This device" altında öz Tailscale IP-ni gör

Sonra `install-wazuh-agent.ps1` skriptini `<VM_IP>` yerinə **VM-in
Tailscale IP-sini** verərək işlət (məs. `.\install-wazuh-agent.ps1 -ManagerIP "100.x.x.x"`).

Bu üsulla Windows Firewall-da əlavə giriş (inbound) qaydası açmağa
ehtiyac yoxdur — host maşın Manager-ə çıxış (outbound) bağlantısı
qurur.

## Tez-tez Verilən Suallar

**S: VM-in IP-si dəyişəndə (restart, yenidən yaratma) nə edim?**
C: Windows-da agent-in konfiqurasiyasını yenilə:
```powershell
# ossec.conf-da <address> sətrini yeni IP ilə əvəz et, sonra:
Restart-Service WazuhSvc
```
Tailscale istifadə etsən, bu problem olmur — Tailscale IP-lər sabitdir.

**S: `docker: command not found` (VM-də) alıram**
C: Docker quraşdırma addımını (yuxarı, 1-ci bölmə) təkrar et.

**S: Dashboard açılmır**
C: 60-90 saniyə gözlə. VM-də yoxla: `docker ps` — bütün konteynerlər
"Up" statusda olmalıdır.

**S: Agent "SSL error, Connection refused" verir**
C: Manager-in (VM-in) özü sağlam açılıb-açılmadığını yoxla:
```bash
docker logs single-node-wazuh.manager-1 2>&1 | grep -i error
docker exec single-node-wazuh.manager-1 ps aux | grep -E "authd|analysisd|remoted"
```
Bax: `DEPLOYMENT_GUIDE.md` → "Problemlərin Həlli" bölməsi.

**S: IOC sayı 0 gəlir**
C: Feed mənbələri (abuse.ch) müvəqqəti əlçatmaz ola bilər. Bir neçə
dəqiqə sonra VM-də `./refresh_iocs.sh` təkrar sına.
