# F.A.S.T. — OSINT Threat Aggregation + Fast-Deploy SIEM

**[F.A.S.T.](#fast)** = Fully Automated SIEM & Threat-Intel Tool

Açıq mənbəli (OSINT) təhdid kəşfiyyatını sürətli yerləşdirilən Wazuh
SIEM ilə birləşdirən threat aggregation platformasıdır. Dörd pulsuz
feed-dən IP/CIDR, URL və hash IOC-ları toplayır, normallaşdırır,
təkrarlanan qeydləri birləşdirir və confidence score hesablayır.
IP/CIDR IOC-ları Wazuh CDB siyahısına ötürülərək hadisələrin `srcip`
sahəsində real-time aşkarlama üçün istifadə olunur.

## 🎯 Məqsəd

Qısamüddətli tədbirlərdə (CTF, təlim, pentest) işləyən SOC komandaları
üçün — kommersiya SIEM lisenziyası və saatlarla quraşdırma olmadan,
sıfır-xərcli, portativ monitorinq mühiti.

## ⚡ Sürətli Başlanğıc

### Tələblər

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

### Deployment

**Tövsiyə olunan ssenari:** Wazuh SIEM cloud Ubuntu VM-də işləyir.
Windows, macOS və ya Linux host isə Wazuh Agent vasitəsilə Manager-ə
qoşulur.

Cloud VM-ə SSH ilə qoşulduqdan sonra:

```bash
git clone --branch dev --single-branch \
  https://github.com/RaminIsmailsoy/fast.git fast-siem
cd fast-siem
./deploy.sh
```

Deployment tamamlandıqdan sonra Dashboard aşağıdakı ünvanda açılır:

```text
https://<VM_IP>
```

İlk deployment adətən 5–10 dəqiqə çəkir. Müddət internet sürətindən,
server resurslarından və Docker image-lərinin endirilmə vaxtından asılıdır.

Ətraflı quraşdırma və agent qoşulması üçün
[Deployment Guide](docs/DEPLOYMENT_GUIDE.md) sənədinə baxın.

> **Qeyd:** Lokal test üçün `deploy.sh` Linux və ya WSL2 mühitində
> işlədilə bilər. Bu halda Dashboard `https://localhost` ünvanında açılır.

Manager IP-ni əl ilə göstərmək üçün:

```bash
./deploy.sh --ip <MANAGER_IP>
```

IP verilmədikdə skript Tailscale, public və lokal IP ardıcıllığı ilə
Manager ünvanını avtomatik müəyyənləşdirməyə çalışır.

### Dashboard-a Giriş

Deployment tamamlandıqdan sonra:

```text
URL:      https://<MANAGER_IP>
Username: admin
Password: SecretPassword
```

İlk girişdən dərhal sonra default parolu dəyişin. Dashboard self-signed
TLS sertifikatı istifadə etdiyi üçün brauzer ilk girişdə sertifikat
xəbərdarlığı göstərə bilər.

## 🧩 Necə İşləyir

```text
4 açıq feed → collect → normalize + dedup + score → SQLite
IP/CIDR → Wazuh CDB ioc-ips → srcip lookup → level 12 alert
URL/hash → CSV/JSON export (Wazuh detection hələ tətbiq edilməyib)
```

1. **OSINT IOC Collector** (Python) — Feodo Tracker, URLhaus,
   MalwareBazaar, Spamhaus DROP-dan IOC yığır
2. **Normalizasiya + Dedup + Scoring** — vahid sxem, təkrarsız, neçə
   feed-də görünməsinə əsasən etibarlılıq balı
3. **Wazuh SIEM** (Docker) — Manager, Indexer və Dashboard
   komponentlərindən ibarətdir. IP/CIDR IOC-ları CDB siyahısı vasitəsilə
   event-lərin `srcip` sahəsi ilə müqayisə edilir və uyğunluq olduqda
   level 12 alert yaradılır.

## Dəstəklənən Feed-lər

1. **Feodo Tracker** — Botnet C2 IP adresləri
2. **URLhaus** — Zərərli URL-lər
3. **MalwareBazaar** — Malware hash-ləri (MD5, SHA256)
4. **Spamhaus DROP** — Spam/botnet IP diapazonları

## Texnologiyalar

- Python 3.11+, SQLite3, requests, pytest (56 avtomatlaşdırılmış test)
- Wazuh OSS (Manager + Indexer + Dashboard)
- Docker, Docker Compose, Bash

## Layihə Strukturu

```text
fast-siem/
├── core/                        # IOC Collector-un əsas modulları
│   ├── db.py                    # SQLite CRUD və dedup
│   ├── exporter.py              # CSV və JSON export
│   ├── fetchers.py              # Dörd OSINT feed fetcher-i
│   ├── normalizer.py            # IOC normalizasiyası
│   ├── scoring.py               # Confidence score hesablanması
│   └── wazuh_export.py          # IP/CIDR üçün Wazuh CDB export
├── docker/
│   ├── ioc-collector.Dockerfile # IOC Collector Docker image-i
│   └── rules/local_rules.xml    # Wazuh IP detection qaydaları
├── docs/
│   ├── DEPLOYMENT_GUIDE.md      # Ətraflı deployment təlimatı
│   ├── USAGE_QUICK_REFERENCE.md # Sürətli istifadə arayışı
│   ├── feed_map.md              # Feed sahələrinin xəritəsi
│   └── user_guide.md            # CLI istifadə təlimatı
├── infra/
│   ├── ansible/                 # Alternativ Ansible deployment
│   ├── cloud-init/              # VM ilkin konfiqurasiyası
│   ├── docs/cost-control.md     # Cloud xərc nəzarəti
│   ├── terraform/               # Cloud infrastruktur kodu
│   └── README.md                # IaC deployment sənədi
├── linux/
│   └── install-wazuh-agent.sh   # Linux agent quraşdırma skripti
├── sample_output/
│   ├── ioc_export.csv           # Nümunə CSV export
│   └── ioc_export.json          # Nümunə JSON export
├── templates/
│   └── index.html               # Flask dashboard şablonu
├── tests/                       # 56 avtomatlaşdırılmış pytest testi
├── windows/
│   └── install-wazuh-agent.ps1  # Windows agent quraşdırma skripti
├── app.py                       # Lokal Flask web interfeysi
├── cli.py                       # Terminal interfeysi
├── deploy.sh                    # Wazuh və IOC tam deployment
├── refresh_iocs.sh              # Əl ilə və ya cron ilə IOC yeniləmə
├── PROJECT_STRUCTURE.txt        # Əlavə struktur arayışı
├── requirements.txt             # Python dependency-ləri
├── USAGE.txt                    # Əlavə istifadə arayışı
└── README.md                    # Əsas layihə sənədi
```

## CLI İstifadəsi (yalnız IOC Collector, SIEM olmadan)

Wazuh SIEM quraşdırmadan yalnız IOC Collector-u istifadə etmək üçün
Python 3.11 və ya daha yeni versiya tələb olunur.

Virtual mühit yaradın və dependency-ləri quraşdırın:

```bash
python3 --version
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
```

Dörd feed-dən IOC-ları toplayıb database-ə yazın:

```bash
python cli.py --fetch
```

`--fetch` əmri database mövcud deyilsə onu avtomatik yaradır.

### CLI parametrləri

| Parametr | Təyinat |
|---|---|
| `--init-db` | Boş SQLite database yaradır |
| `--fetch` | IOC-ları toplayır, normallaşdırır və database-ə yazır |
| `--show` | Database-dəki IOC-ları terminalda göstərir |
| `--count` | Unikal IOC sayını göstərir |
| `--export csv` | Bütün IOC-ları CSV faylına çıxarır |
| `--export json` | Bütün IOC-ları JSON faylına çıxarır |
| `--export both` | CSV və JSON fayllarını birlikdə yaradır |
| `--export wazuh` | Yalnız IP/CIDR IOC-ları Wazuh CDB-yə çıxarır |

Bir neçə əməliyyatı eyni əmrdə icra etmək mümkündür:

```bash
python cli.py --fetch --export both --count
```

Export faylları `sample_output/` qovluğunda yaradılır.

## Lokal Web İnterfeysi

IOC-ları brauzerdən görmək və idarə etmək üçün Flask əsaslı lokal web
interfeysi mövcuddur.

Virtual mühit aktiv olduqdan və dependency-lər quraşdırıldıqdan sonra:

```bash
python app.py
```

Dashboard aşağıdakı ünvanda açılır:

```text
http://localhost:5000
```

Web interfeysi IOC siyahısını göstərmək, axtarış və filtr tətbiq etmək,
feed-lərdən yeni məlumat toplamaq, statistikanı görmək və CSV/JSON
export yaratmaq imkanları verir.

> **Təhlükəsizlik qeydi:** Hazırkı Flask tətbiqi development server və
> debug rejimindən istifadə edir. Onu internetə açmayın və production
> mühitində olduğu kimi istifadə etməyin.

## IOC-ların Yenilənməsi

Deployment tamamlandıqdan sonra IOC-ları əl ilə yeniləmək üçün:

```bash
./refresh_iocs.sh
```

Skript cron job-u avtomatik yaratmır. Avtomatik gündəlik yeniləmə üçün
cron job istifadəçi tərəfindən ayrıca əlavə edilməlidir. Məsələn, hər
gün saat 03:00-da:

```cron
0 3 * * * /opt/fast/refresh_iocs.sh >> /var/log/fast-refresh.log 2>&1
```

Bu skript `deploy.sh` uğurla tamamlandıqdan və
`osint-ioc-collector` Docker image-i yaradıldıqdan sonra işlədilməlidir.

## Verilənlər Bazası Sxemi

```text
ioc (table)
├── id                INTEGER PRIMARY KEY
├── ioc_value         TEXT (IP/Domain/Hash/URL)
├── ioc_type          TEXT (ip, domain, hash, url)
├── source_feed       TEXT (feodo, urlhaus, ...)
├── first_seen        DATETIME
├── last_seen         DATETIME
├── confidence_score  INTEGER (feed sayına görə: 25/50/75/100)
└── tags              TEXT (JSON array)
```

**Qeyd:** Sxem `ip`, `domain`, `hash` və `url` IOC tiplərini nəzərdə tutur.
Hazırkı dörd feed-in normalizer-ləri isə `ip`, `url` və `hash` tipli IOC-lar yaradır.

## Xəta Toleration

- Feed əlçatan deyilsə → log yazıb davam et, crash yoxdur
- Dedup: eyni `ioc_value + ioc_type` varsa → `last_seen` yenilə, insert etmə
- Scoring: neçə fərqli feed-də görünübsə, bal bir o qədər yüksəkdir

## Akronimlər və Terminlər

[F.A.S.T.](#fast) · [T.A.L.O.N.](#talon) · [IOC](#ioc) ·
[CDB](#cdb) · [LOLBin](#lolbin) · [SLO](#slo)

<!-- pyml disable-next-line MD026 -->
### F.A.S.T.

**Fully Automated SIEM & Threat-Intel Tool** — OSINT IOC-larını toplayan
və IP əsaslı aşkarlama üçün Wazuh ilə inteqrasiya edən platformadır.

<!-- pyml disable-next-line MD026 -->
### T.A.L.O.N.

**Threat Aggregator & Local OSINT Node** — threat intelligence
məlumatlarını lokal səviyyədə toplayan və emal edən node-dur.

### IOC

**Indicator of Compromise** — mümkün kiberhücumu və ya komprometi
göstərən IP, URL, domain və ya fayl hash-i kimi göstəricidir.

### CDB

**Constant Database** — Wazuh-un detection qaydalarında sürətli
key-value lookup üçün istifadə etdiyi siyahı formatıdır.

### LOLBin

**Living Off the Land Binary** — hücumçunun zərərli məqsədlər üçün
istifadə edə bildiyi legitim sistem proqramıdır.

### SLO

**Service Level Objective** — xidmətin performans və etibarlılığı üçün
müəyyən edilmiş ölçülə bilən hədəfdir.

## Testlər

Virtual mühit aktiv olduqdan sonra bütün dependency-ləri və testləri
işə salın:

```bash
python -m pip install -r requirements.txt
python -m pytest tests/ -v
```

Yoxlama zamanı Python 3.12.13 üzərində bütün testlər uğurla keçdi:

```text
56 passed
```

---

**Layihə:** F.A.S.T. (Fully Automated SIEM & Threat-Intel Tool)
**Tələbələr:** Islam, Elmir, Nihat, Ramin
