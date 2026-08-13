# Feed Xəritəsi (Feed Mapping)

Hər feed-dən gələn məlumatların standart sxemə necə map olunduğunu izah edir.

## 1. Feodo Tracker

**Feed URL:** `https://feodotracker.abuse.ch/downloads/ipblocklist.json`

**Format:** JSON

**Raw Struktur:**
```json
{
  "botnet": "dridex",
  "ip_address": "192.168.1.1",
  "port": "443",
  "country_code": "RU",
  "last_dns_query": "2024-01-15"
}
```

**Mapping:**
| Feodo Sahəsi | Standart Sahə | Qeyd |
|---|---|---|
| `ip_address` | `ioc_value` | IP ünvanı |
| - | `ioc_type` | `"ip"` |
| - | `source_feed` | `"feodo"` |
| `last_dns_query` | `last_seen` | Tarix parse edilir |
| - | `first_seen` | `last_seen` ilə eyni |
| `botnet` | `tags` | Botnet adı tag olaraq |

---

## 2. URLhaus

**Feed URL:** `https://urlhaus.abuse.ch/downloads/csv_recent/`

**Format:** CSV

**Raw Struktur:**
```csv
id,date_added,url,url_status,threat,reporter
1,2024-01-15,http://evil.com/malware.exe,online,Trojan,abuse.ch
```

**Mapping:**
| URLhaus Sahəsi | Standart Sahə | Qeyd |
|---|---|---|
| `url` | `ioc_value` | URL ünvanı |
| - | `ioc_type` | `"url"` |
| - | `source_feed` | `"urlhaus"` |
| `date_added` | `first_seen` | Tarix parse edilir |
| `date_added` | `last_seen` | Tarix parse edilir |
| `threat` | `tags` | Threat tipi tag olaraq |

---

## 3. MalwareBazaar

**Feed URL:** `https://bazaar.abuse.ch/export/csv/recent/`

**Format:** CSV

**Raw Struktur:**
```csv
sha256,md5,first_submission,last_analysis,file_name
abc123,def456,2024-01-10,2024-01-15,malware.exe
```

**Mapping:**
| MalwareBazaar Sahəsi | Standart Sahə | Qeyd |
|---|---|---|
| `sha256` veya `md5` | `ioc_value` | Hash dəyəri |
| - | `ioc_type` | `"hash"` |
| - | `source_feed` | `"malwarebazaar"` |
| `first_submission` | `first_seen` | Tarix parse edilir |
| `last_analysis` | `last_seen` | Tarix parse edilir |
| `file_name` | `tags` | Fayl adı tag olaraq |

---

## 4. Spamhaus DROP

**Feed URL:** `https://www.spamhaus.org/drop/drop.txt`

**Format:** Plain Text (Hər sətrdə IP, `; "REASON"` ilə)

**Raw Struktur:**
```
; Spamhaus DROP List
192.168.1.0/24 ; "Botnet"
10.0.0.0/8 ; "Spam Source"
```

**Mapping:**
| Spamhaus Sahəsi | Standart Sahə | Qeyd |
|---|---|---|
| IP ünvanı | `ioc_value` | CIDR və ya IP |
| - | `ioc_type` | `"ip"` |
| - | `source_feed` | `"spamhaus"` |
| - | `first_seen` | Cari tarix |
| - | `last_seen` | Cari tarix |
| Kömenti (`REASON`) | `tags` | Səbəb tag olaraq |

---

## Standart Çıxış Sxemi

```json
{
  "ioc_value": "192.168.1.1",
  "ioc_type": "ip",
  "source_feed": "feodo",
  "first_seen": "2024-01-10T10:30:00",
  "last_seen": "2024-01-15T15:45:00",
  "confidence_score": 75,
  "tags": ["botnet", "dridex"]
}
```

---

**Son Yeniləmə:** 2026-08-07
