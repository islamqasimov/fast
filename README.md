# F.A.S.T. — OSINT Threat Aggregation + Fast-Deploy SIEM

**F.A.S.T.** = Fully Automated SIEM & Threat-Intel Tool

Açıq mənbəli (OSINT) təhdid kəşfiyyatını sürətli yerləşdirilən Wazuh SIEM
ilə birləşdirən threat aggregation platforması. 4 pulsuz feed-dən IOC
yığır, normallaşdırır, dedup edir və Wazuh-a real-time detection
qaydaları kimi ötürür — hamısı **tək bir skriptlə, dəqiqələr ərzində**.

## 🎯 Məqsəd

Qısamüddətli tədbirlərdə (CTF, təlim, pentest) işləyən SOC komandaları
üçün — kommersiya SIEM lisenziyası və saatlarla quraşdırma olmadan,
sıfır-xərcli, portativ monitorinq mühiti.

## ⚡ Sürətli Başlanğıc

**Tövsiyə olunan ssenari:** Wazuh SIEM cloud Ubuntu VM-də işləyir, sən isə
öz host maşınından (Windows/Mac/Linux) Wazuh Agent ilə ona qoşulursan.

**Cloud VM-də** (SSH ilə qoşulub):
```bash
git clone <bu-repo-url> fast-siem
cd fast-siem
./deploy.sh
```

5-10 dəqiqə sonra: Wazuh Dashboard VM-in IP-si üzərindən açıq
(`https://<VM_IP>`), IOC-lar axır. Ətraflı: [`docs/DEPLOYMENT_GUIDE.md`](docs/DEPLOYMENT_GUIDE.md)

**Sənin host maşınında:** Wazuh Agent quraşdırıb Manager-ə (cloud VM-ə)
qoşulursan — addımlar üçün bax: [`docs/DEPLOYMENT_GUIDE.md`](docs/DEPLOYMENT_GUIDE.md#wazuh-agent-qoşmaq-log-toplama-üçün)

> Lokal (öz kompüterində) sınaq üçün eyni `./deploy.sh` sənin öz
> maşınında da işləyir — bu halda `https://localhost` istifadə olunur.

> IP-ni əl ilə göstərmək üçün: `./deploy.sh --ip <MANAGER_IP>`.
> Verilməzsə, skript sonunda IP-ni özü aşkarlayıb agent-qoşma
> əmrlərini hazır formada çap edir.

## 🧩 Necə İşləyir

```
4 açıq feed → IOC Collector → normalize+dedup+score → Wazuh CDB list → Wazuh Manager → real-time alert
```

1. **OSINT IOC Collector** (Python) — Feodo Tracker, URLhaus,
   MalwareBazaar, Spamhaus DROP-dan IOC yığır
2. **Normalizasiya + Dedup + Scoring** — vahid sxem, təkrarsız, neçə
   feed-də görünməsinə əsasən etibarlılıq balı
3. **Wazuh SIEM** (Docker) — Manager+Indexer+Dashboard, IOC-lar CDB list
   formatında real-time detection qaydalarına bağlanır

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

```
fast-siem/
├── core/                       # OSINT IOC Collector - əsas funksionallıq
│   ├── fetchers.py            # 4 feed fetcher
│   ├── normalizer.py          # Normallaşdırma
│   ├── db.py                  # SQLite CRUD + dedup + avtomatik scoring
│   ├── scoring.py             # Confidence scoring məntiqi
│   ├── exporter.py            # CSV/JSON export
│   └── wazuh_export.py        # Wazuh CDB list export
├── docker/
│   ├── ioc-collector.Dockerfile
│   └── rules/local_rules.xml         # IOC detection qaydaları (docker cp ilə tətbiq olunur)
├── windows/
│   └── install-wazuh-agent.ps1       # Windows host üçün avtomatik Agent quraşdırma
├── tests/                      # pytest testləri (56 test)
├── docs/
│   ├── DEPLOYMENT_GUIDE.md    # Addım-addım quraşdırma
│   ├── USAGE_QUICK_REFERENCE.md      # Sürətli istinad (Windows + WSL)
│   ├── feed_map.md            # Feed sahələrinin xəritəsi
│   └── user_guide.md          # CLI istifadə təlimatı
├── infra/                      # (Alternativ) Terraform+Ansible cloud IaC
│                                # - əsas yol deyil, bax infra/README.md
├── sample_output/              # Nümunə export faylları
├── cli.py                      # Terminal interfeysi
├── deploy.sh                   # ⭐ TƏK-SKRİPTLİ TAM DEPLOYMENT
├── refresh_iocs.sh             # IOC-ları yeniləmə (manual/cron)
├── requirements.txt
└── README.md                   # Bu fayl
```

## CLI İstifadəsi (yalnız IOC Collector, SIEM olmadan)

```bash
pip install -r requirements.txt
python cli.py --init-db
python cli.py --fetch                # Bütün feed-lərdən yığ
python cli.py --show                 # Nəticələri göstər
python cli.py --export csv           # CSV export
python cli.py --export json          # JSON export
python cli.py --export wazuh         # Wazuh CDB list export
```

## Verilənlər Bazası Sxemi

```
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

## Xəta Toleration

- Feed əlçatan deyilsə → log yazıb davam et, crash yoxdur
- Dedup: eyni `ioc_value + ioc_type` varsa → `last_seen` yenilə, insert etmə
- Scoring: neçə fərqli feed-də görünübsə, bal bir o qədər yüksəkdir

## Testlər

```bash
pip install pytest
python -m pytest tests/ -v   # 56 test
```

---

**Layihə:** F.A.S.T. (Fully Automated SIEM & Threat-Intel Tool) | **Tələbələr:** Islam, Elmir, Nihat, Ramin
