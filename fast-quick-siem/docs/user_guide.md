# İstifadəçi Təlimatı

OSINT IOC Collector-u necə istifadə etməli?

## Quraşdırma

### 1. Layihəni klonla

```bash
git clone <repo-url>
cd osint-ioc-collector
```

### 2. Virtual Environment yaradılması (isteğə bağlı, lakin tövsiyə olunur)

```bash
python -m venv venv
source venv/bin/activate  # Linux/Mac
venv\Scripts\activate    # Windows
```

### 3. Asılılıqları quraşdır

```bash
pip install -r requirements.txt
```

### 4. Verilənlər Bazasını başlat

```bash
python cli.py --init-db
```

---

## Terminal (CLI) istifadəsi

### Bütün feed-lərdən yığ

```bash
python cli.py --fetch
```

**Çıxış:**
```
2026-08-07 10:30:45 - root - INFO - Feodo Tracker-dən 150 IOC yığıldı
2026-08-07 10:31:02 - root - INFO - URLhaus-dan 280 IOC yığıldı
2026-08-07 10:31:45 - root - INFO - MalwareBazaar-dan 95 IOC yığıldı
2026-08-07 10:32:15 - root - INFO - Spamhaus-dan 420 IOC yığıldı
Cəmi: 945 IOC yığıldı
```

### IOC-ları göstər

```bash
python cli.py --show
```

### Toplam IOC sayını göstər

```bash
python cli.py --count
```

**Çıxış:**
```
Bazadakı toplam IOC sayı: 2,350
```

### CSV olaraq export

```bash
python cli.py --export csv
```

**Çıxış:** `sample_output/ioc_export.csv`

### JSON olaraq export

```bash
python cli.py --export json
```

**Çıxış:** `sample_output/ioc_export.json`

---

## Veb Interface istifadəsi

### Serveri başlat

```bash
python app.py
```

**URL:** `http://localhost:5000`

### Dashboard

- Əsas səhifə: IOC statistikası
- Toplam IOC sayı
- IOC tip-ə görə bölgüsü (IP, Domain, Hash, URL)
- Feed-ə görə bölgüsü

### API Endpoints

#### Bütün IOC-ları al (JSON)

```
GET /api/iocs
```

**Response:**
```json
[
  {
    "ioc_value": "192.168.1.1",
    "ioc_type": "ip",
    "source_feed": "feodo",
    "first_seen": "2024-01-10",
    "last_seen": "2024-01-15",
    "confidence_score": 75,
    "tags": ["botnet", "dridex"]
  },
  ...
]
```

#### Feed-lərdən yığ

```
POST /api/fetch
```

#### Export et

```
GET /api/export?format=csv
GET /api/export?format=json
```

#### Statistika al

```
GET /api/stats
```

---

## Avtomatik Scheduler (İsteğə bağlı)

Gündə bir dəfə otomatik olaraq feed-lərdən yığmaq üçün:

```bash
python scheduler.py
```

**Tənzimləmə:** `scheduler.py` faylında saatı dəyişə bilərsən.

---

## Xəta Həll Etmə

### Baza açılmırsa

```bash
rm ioc_database.db
python cli.py --init-db
```

### Feed çəkilmir

- Feed məsul verən saytın vəziyyətini yoxla
- VPN istifadə etməyi cəhd et
- Loqlara bax: `python cli.py --fetch 2>&1 | grep ERROR`

### Yavaş export

- Çox sayda IOC varsa (>10K), JSON export-u istifadə et (daha sürətli)

---

## Məsuliyyət

Bu layihə **yalnız qanuni OSINT məqsədləri üçün** istifadə edilməlidir.

Threat Intelligence-i məsuliyyətli istifadə edin.

---

**Son Yeniləmə:** 2026-08-07
