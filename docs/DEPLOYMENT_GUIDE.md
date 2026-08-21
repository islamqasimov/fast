# F.A.S.T. — Deployment Guide

Bu sənəd F.A.S.T. (OSINT IOC Collector + Wazuh SIEM) mühitini sıfırdan necə
dəqiqələr ərzində ayağa qaldıracağını izah edir.

## Tələblər

- Ən azı 4 CPU nüvəsi, 8 GB RAM və 50 GB boş disk
- Docker Engine və Docker Compose plugin
- Git
- İnternet bağlantısı
- Linux host və ya Windows üzərində WSL2

Linux və WSL2 host-da Wazuh Indexer üçün aşağıdakı kernel parametrini
təyin edin:

```bash
sudo sysctl -w vm.max_map_count=262144
```

Tələb olunan proqramları yoxlayın:

```bash
docker --version
docker compose version
git --version
```

Docker quraşdırılması üçün rəsmi
[Docker Engine sənədlərinə](https://docs.docker.com/engine/install/)
baxın.

## Sürətli Başlanğıc (Tək Əmr)

**Tövsiyə olunan ssenari:** Wazuh SIEM cloud Ubuntu VM-də işləyir.
Aşağıdakı əmrləri VM-ə SSH ilə qoşulub, orada icra edin:

```bash
git clone <bu-repo-url> fast-siem
cd fast-siem
./deploy.sh
```

Manager IP-ni əl ilə göstərmək üçün:
```bash
./deploy.sh --ip <MANAGER_IP>
```

IP verilmədikdə skript Tailscale, public və lokal IP ardıcıllığı ilə
Manager ünvanını avtomatik müəyyənləşdirməyə çalışır.

> **Qeyd:** Lokal sınaq üçün eyni skript Linux və ya WSL2 mühitində
> işlədilə bilər. Bu halda Manager ünvanı `localhost` olacaq.

Bu qədər. Skript aşağıdakıları avtomatik edir:

1. Rəsmi Wazuh Docker stack-ini endirir (ilk dəfə, ~1 dəq)
2. SSL sertifikatları generasiya edir (ilk dəfə, ~1 dəq)
3. OSINT IOC Collector-un custom detection qaydasını Wazuh-a bağlayır
4. Wazuh Manager+Indexer+Dashboard-ı işə salır (`docker compose up -d`)
5. IOC Collector image-ni tikir
6. 4 açıq feed-dən (Feodo, URLhaus, MalwareBazaar, Spamhaus) IOC yığır,
   normallaşdırır, dedup edir, confidence score hesablayır
7. IP tipli IOC-ları Wazuh CDB list formatına çevirir
8. CDB list-i Wazuh Manager konteynerinə köçürüb tətbiq edir

**Ümumi vaxt: ~5-10 dəqiqə** (əsasən Docker image-lərin yüklənməsi).

## Nəticəni Yoxlamaq

Brauzerdə aç: **`https://<VM_PUBLIC_IP>`** (yaxud lokal işlətmisənsə `https://localhost`)

VM-in public IP-sini tapmaq üçün: `curl ifconfig.me` (VM-in özündə işlət).

- İstifadəçi: `admin`
- Parol: `SecretPassword` (Wazuh-un default parolu — **ilk girişdə mütləq dəyiş**)

Dashboard-da sol menyudan **Threat Intelligence → Rules** bölməsinə keçib
`100100`-`100102` ID-li custom qaydaların mövcud olduğunu yoxla.

## IOC-ları Yeniləmək

Deploy prosesini təkrarlamadan, yalnız yeni IOC yığmaq üçün:

```bash
./refresh_iocs.sh
```

Avtomatik (gündəlik) yeniləmə üçün, host maşının cron-una əlavə et:

```bash
crontab -e
# Aşağıdakı sətri əlavə et:
0 3 * * * /tam/yol/osint-ioc-collector/refresh_iocs.sh >> /var/log/fast-refresh.log 2>&1
```

## Wazuh Agent Qoşmaq (Log Toplama Üçün)

Manager cloud VM-də işlədiyi üçün, VM-in adətən public IP-si var və agent
birbaşa ona qoşula bilir. Əgər VM-i internetə açmaq istəmirsənsə (yalnız
öz cihazlarından giriş), **Tailscale** ilə şəxsi şəbəkə qurub, agent-i
Manager-in Tailscale IP-si üzərindən qoşmaq tövsiyə olunur (bax: aşağı,
"Tailscale ilə Təhlükəsiz Bağlantı").

### Windows Host Maşında (Avtomatik Skript — Tövsiyə Olunur)

`windows/install-wazuh-agent.ps1` skripti endirmə, quraşdırma,
konfiqurasiya və servis başlatmanı tək əmrlə edir, həm də əvvəlcədən
Manager-in əlçatan olub-olmadığını yoxlayır.

**PowerShell-i Administrator kimi aç:**

```powershell
cd fast-siem\windows
.\install-wazuh-agent.ps1 -ManagerIP "<MANAGER_IP>"
```

`<MANAGER_IP>` yerinə Wazuh Manager-in işlədiyi VM-in IP-sini (public IP
və ya Tailscale IP) yaz. İstəyə bağlı olaraq agent-ə xüsusi ad da
verə bilərsən:

```powershell
.\install-wazuh-agent.ps1 -ManagerIP "<MANAGER_IP>" -AgentName "elmir-laptop"
```

Skript avtomatik olaraq:
- Administrator hüququnu yoxlayır
- 1514/1515 portlarının Manager-də əlçatan olduğunu test edir
- MSI-ni endirib quraşdırır
- Servisi başladır və son log qeydlərini göstərir

<details>
<summary>Əl ilə quraşdırma (skript istifadə etmək istəməsən)</summary>

```powershell
Invoke-WebRequest -Uri https://packages.wazuh.com/4.x/windows/wazuh-agent-4.9.0-1.msi -OutFile wazuh-agent.msi
msiexec.exe /i wazuh-agent.msi /q WAZUH_MANAGER="<MANAGER_IP>" WAZUH_REGISTRATION_SERVER="<MANAGER_IP>"
NET START WazuhSvc
```

</details>

### Linux Hədəf Maşında (əlavə target üçün, əgər lazımdırsa)

```bash
curl -so wazuh-agent.deb https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.9.0-1_amd64.deb
sudo WAZUH_MANAGER='<MANAGER_IP>' dpkg -i ./wazuh-agent.deb
sudo systemctl daemon-reload
sudo systemctl enable wazuh-agent
sudo systemctl start wazuh-agent
sudo systemctl status wazuh-agent
```

### Qoşulmanı Təsdiqləmək

Manager tərəfdə (VM-də, Wazuh konteynerinin işlədiyi yerdə):

```bash
docker exec single-node-wazuh.manager-1 /var/ossec/bin/agent_control -l
```

Yeni agent-in **Active** statusda göründüyünü görməlisən. Dashboard-da
da: **Agents** bölməsindən yoxlana bilər.

### Tailscale ilə Təhlükəsiz Bağlantı (tövsiyə olunur)

Əgər Manager VM-i internetə açmaq istəmirsənsə, ya da host maşın NAT
arxasındadırsa (adi ev/ofis şəbəkəsi), **Tailscale** hər iki tərəfi
(host + VM) port-forwarding olmadan, şifrəli birbaşa bağlantı ilə
qoşur:

1. https://tailscale.com/ — hesab yarat (pulsuz)
2. VM-də: `curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up`
3. Windows host-da: https://tailscale.com/download/windows — quraşdır, giriş et
4. Hər ikisində `tailscale ip -4` ilə sabit Tailscale IP-lərini tap
5. Agent qoşulma addımlarında `<MANAGER_IP>` yerinə **VM-in Tailscale
   IP-sini** istifadə et (məs. `100.x.x.x`)

Bu üsulla, Windows Firewall-da əlavə inbound qayda açmağa ehtiyac
qalmır — çünki host maşın (agent) Manager-ə **çıxış (outbound)**
bağlantısı qurur, giriş (inbound) qaydası lazım deyil.

## Dayandırmaq / Silmək

```bash
# Müvəqqəti dayandırmaq (data qalır)
cd wazuh-docker/single-node
docker compose down

# Yenidən işə salmaq
docker compose up -d

# Tam silmək (data daxil)
docker compose down -v
cd ../..
rm -rf wazuh-docker
```

## Problemlərin Həlli

| Problem | Həll |
|---|---|
| `docker: command not found` | Docker quraşdır: https://docs.docker.com/engine/install/ |
| Dashboard açılmır | 60-90 saniyə gözlə, `docker ps` ilə konteynerlərin `Up` statusda olduğunu yoxla |
| `vm.max_map_count` xətası | `sudo sysctl -w vm.max_map_count=262144` işlət (Wazuh Indexer tələbi) |
| IOC-lar 0 gəlir | Feed mənbələri (abuse.ch) müvəqqəti əlçatmaz ola bilər — `docker run ... osint-ioc-collector --show` ilə bazanı yoxla, bir neçə dəqiqə sonra `./refresh_iocs.sh` təkrar sına |
| Manager `ar.conf` xətası ilə açılmır, `authd`/`analysisd` prosesi yoxdur | Köhnə `wazuh-docker/single-node/docker-compose.override.yml` faylı qalıbsa sil (`rm wazuh-docker/single-node/docker-compose.override.yml`), sonra `docker compose down -v && docker compose up -d`. `deploy.sh`-in cari versiyası bunu avtomatik aşkarlayıb silir, amma köhnə versiya ilə quraşdırılmış mühitlərdə əl ilə lazım ola bilər. Kök səbəb: `/var/ossec/etc/lists` kimi qovluqları bütövlükdə bind-mount etmək Wazuh-un ilkin fayl strukturunu yaratma prosesini pozur — bax aşağıdakı izah |
| Agent "SSL error, Connection refused" verir | Manager-in özü sağlam deyilsə (yuxarı sətrə bax) agent heç vaxt qoşula bilməz. Əvvəlcə Manager-i düzəlt, sonra agent-i restart et |

## Texniki Qeyd: Niyə `docker cp` İstifadə Olunur, Bind-Mount Yox

İlkin versiyada custom detection qaydası (`local_rules.xml`) və IOC CDB
list-i (`ioc-ips`) `docker-compose.override.yml` vasitəsilə bind-mount
edilirdi — yəni Wazuh Manager konteyneri **açılan zaman** bu fayllar
artıq host-dan mount olunmuş vəziyyətdə idi.

Bu, real istifadədə problem yaratdı: Wazuh-un öz init prosesi
(`wazuh-analysisd`) `/var/ossec/etc/lists` qovluğunun **tam öz nəzarəti
altında** olmasını gözləyir — ora daxilində öz ilkin fayllarını
(`ar.conf` və s.) yaradır. Bu qovluğu (və ya onun daxilindəki
`etc_lists`-i) bütövlükdə host-dan bind-mount etdikdə, Wazuh həmin
ilkin faylları yarada bilmir və `analysisd` "Configuration error"
ilə çıxır — nəticədə `authd` (agent qeydiyyat xidməti) heç vaxt
başlamır, agent-lər "SSL error, Connection refused" alır.

**Həll:** Manager həmişə **tam default konfiqurasiya ilə** açılır
(heç bir bind-mount yoxdur), sağlamlığı təsdiqlənir (`authd`,
`analysisd`, `remoted` proseslərinin işlədiyi və loglarda CRITICAL
xəta olmadığı yoxlanılır), və yalnız bundan **sonra** `docker cp`
ilə custom fayllar konteynerin daxilinə köçürülür, konteyner restart
edilir. Bu ardıcıllıq `deploy.sh` və `refresh_iocs.sh`-də avtomatik
təmin olunur.

## Harada İşlətməli: Cloud VM vs Lokal

Yuxarıdakı addımlar istənilən Docker dəstəkli mühitdə eyni cür işləyir.
**Tövsiyə olunan ssenari** budur: `deploy.sh` cloud Ubuntu VM-də icra
olunur (Manager, Indexer, Dashboard, IOC Collector — hamısı orada), sən
isə öz host maşınından (yuxarı bölmədə göstərildiyi kimi) Agent ilə ona
qoşulursan. Lokal sınaq üçün eyni skript sənin öz kompüterində də
işləyir — heç bir kod dəyişikliyi lazım deyil, sadəcə haradan
işlətdiyindən asılıdır.

Layihənin `infra/` qovluğunda daha əvvəl hazırlanmış Terraform+Ansible
əsaslı, çoxlu-VM cloud infrastrukturu da mövcuddur (öyrənmə/genişləndirmə
məqsədilə saxlanılıb), lakin bu, **fast deployment** məqsədi üçün tövsiyə
olunan yol deyil — yuxarıdakı `deploy.sh` yanaşması ilə müqayisədə daha
çox vaxt (IAM, VM yaratma, Ansible) tələb edir.
