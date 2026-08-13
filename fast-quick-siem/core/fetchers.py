"""
IOC Feed Fetcher Module

Müxtəlif açıq threat intelligence feed-lərindən IOC-ları çəkməyə məsul modulu.

Dəstəklənən feed-lər:
- Feodo Tracker
- URLhaus  
- MalwareBazaar
- Spamhaus DROP
"""

import logging
import requests
import csv
from typing import List, Dict, Any
from datetime import datetime

logger = logging.getLogger(__name__)

# Feed URL-ləri
FEED_URLs = {
    "feodo": "https://feodotracker.abuse.ch/downloads/ipblocklist.json",
    "urlhaus": "https://urlhaus.abuse.ch/downloads/csv_recent/",
    "malwarebazaar": "https://bazaar.abuse.ch/export/csv/recent/",
    "spamhaus": "https://www.spamhaus.org/drop/drop.txt"
}


def fetch_feodo() -> List[Dict[str, Any]]:
    """
    Feodo Tracker-dən botnet C2 IP adreslərini çəkir.
    
    JSON formatında IP-ləri və əlaqəli metadata-nı qaytarır.
    
    Returns:
        List[Dict]: IOC məlumat siyahısı
        Xəta halında: boş siyahı []
    
    Nümunə çıxışı:
        [
            {
                "botnet": "dridex",
                "ip_address": "192.168.1.1",
                "port": "443",
                "country_code": "RU",
                "last_dns_query": "2024-01-15"
            },
            ...
        ]
    """
    url = FEED_URLs["feodo"]
    iocs = []
    
    try:
        logger.info(f"Feodo Tracker-dən məlumat çəkilir: {url}")
        
        # HTTP sorğusu (User-Agent lazımdır)
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        }
        response = requests.get(url, headers=headers, timeout=15)
        response.raise_for_status()
        
        # JSON parse etmə
        data = response.json()
        
        # `data` bir list ola bilər və ya {"data": [...]} şəkli ola bilər
        if isinstance(data, dict) and "data" in data:
            iocs = data["data"]
        elif isinstance(data, list):
            iocs = data
        else:
            logger.warning("Feodo: Gözlənilməz JSON struktur")
            return []
        
        logger.info(f"Feodo: {len(iocs)} IOC çəkildi")
        return iocs
        
    except requests.exceptions.Timeout:
        logger.error("Feodo Tracker: Timeout (15 san)")
        return []
    except requests.exceptions.ConnectionError:
        logger.error("Feodo Tracker: Bağlantı xətası")
        return []
    except requests.exceptions.HTTPError as e:
        logger.error(f"Feodo Tracker: HTTP {e.response.status_code}")
        return []
    except ValueError:
        logger.error("Feodo Tracker: JSON parse xətası")
        return []
    except Exception as e:
        logger.error(f"Feodo Tracker: Naməlum xəta: {str(e)}")
        return []


def fetch_urlhaus() -> List[Dict[str, Any]]:
    """
    URLhaus-dan zərərli URL-ləri çəkir.
    
    CSV formatında URL-lər, tarix və status məlumatını qaytarır.
    
    Returns:
        List[Dict]: IOC məlumat siyahısı
        Xəta halında: boş siyahı []
    
    Nümunə çıxışı:
        [
            {
                "id": "12345",
                "dateadded": "2024-01-15 10:30:00",
                "url": "http://evil.com/malware.exe",
                "url_status": "online",
                "threat": "malware_download",
                "tags": "exe,trojan",
                "reporter": "abuse_ch"
            },
            ...
        ]
    """
    url = FEED_URLs["urlhaus"]
    iocs = []
    
    try:
        logger.info(f"URLhaus-dan məlumat çəkilir: {url}")
        
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        }
        response = requests.get(url, headers=headers, timeout=15)
        response.raise_for_status()
        
        # URLhaus CSV başlıqda "# " ilə başlayan comment sətirləri var
        # Format: # id,dateadded,url,url_status,threat,tags,urlhaus_link,reporter
        lines = response.text.splitlines()
        
        # Comment olmayan (data) sətirləri tap
        data_lines = [line for line in lines if line and not line.startswith("#")]
        
        if not data_lines:
            logger.warning("URLhaus: Data sətirləri tapılmadı")
            return []
        
        # CSV header-i tap (comment içindəki son "# " sətri, "id," ilə başlayır)
        header_line = None
        for line in lines:
            if line.startswith("# id"):
                header_line = line.lstrip("# ").strip()
                break
        
        if header_line is None:
            # Fallback - default header
            fieldnames = ["id", "dateadded", "url", "url_status", "last_online",
                          "threat", "tags", "urlhaus_link", "reporter"]
        else:
            fieldnames = [h.strip() for h in header_line.split(",")]
        
        reader = csv.DictReader(data_lines, fieldnames=fieldnames)
        for row in reader:
            iocs.append(dict(row))
        
        logger.info(f"URLhaus: {len(iocs)} IOC çəkildi")
        return iocs
        
    except requests.exceptions.Timeout:
        logger.error("URLhaus: Timeout (15 san)")
        return []
    except requests.exceptions.ConnectionError:
        logger.error("URLhaus: Bağlantı xətası")
        return []
    except requests.exceptions.HTTPError as e:
        logger.error(f"URLhaus: HTTP {e.response.status_code}")
        return []
    except csv.Error as e:
        logger.error(f"URLhaus: CSV parse xətası: {str(e)}")
        return []
    except Exception as e:
        logger.error(f"URLhaus: Naməlum xəta: {str(e)}")
        return []


def fetch_malwarebazaar() -> List[Dict[str, Any]]:
    """
    MalwareBazaar-dan malware hash-lərini çəkir.
    
    CSV formatında MD5, SHA256 hash-ləri və əlaqədar data qaytarır.
    
    Returns:
        List[Dict]: IOC məlumat siyahısı
        Xəta halında: boş siyahı []
    
    Nümunə çıxışı:
        [
            {
                "first_seen_utc": "2024-01-15 10:30:00",
                "sha256_hash": "abc123...",
                "md5_hash": "def456...",
                "file_name": "malware.exe",
                "file_type": "exe",
                "signature": "TrojanX",
                "reporter": "abuse_ch"
            },
            ...
        ]
    """
    url = FEED_URLs["malwarebazaar"]
    iocs = []
    
    try:
        logger.info(f"MalwareBazaar-dan məlumat çəkilir: {url}")
        
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        }
        response = requests.get(url, headers=headers, timeout=15)
        response.raise_for_status()
        
        lines = response.text.splitlines()
        data_lines = [line for line in lines if line and not line.startswith("#")]
        
        if not data_lines:
            logger.warning("MalwareBazaar: Data sətirləri tapılmadı")
            return []
        
        # MalwareBazaar header-i comment içindəki son "# " sətrindən tap
        header_line = None
        for line in lines:
            if line.startswith('# "') or line.startswith("# first_seen"):
                header_line = line.lstrip("# ").strip()
                break
        
        if header_line is None:
            fieldnames = ["first_seen_utc", "sha256_hash", "md5_hash", "sha1_hash",
                          "reporter", "file_name", "file_type_guess", "mime_type",
                          "signature", "clamav", "vtpercent", "imphash", "ssdeep", "tlsh"]
        else:
            fieldnames = [h.strip().strip('"') for h in header_line.split(",")]
        
        reader = csv.DictReader(
            data_lines, fieldnames=fieldnames, skipinitialspace=True
        )
        for row in reader:
            # MalwareBazaar dəyərləri dırnaq içindədir, təmizlə
            clean_row = {
                k: (v.strip().strip('"') if isinstance(v, str) else v)
                for k, v in row.items()
            }
            iocs.append(clean_row)
        
        logger.info(f"MalwareBazaar: {len(iocs)} IOC çəkildi")
        return iocs
        
    except requests.exceptions.Timeout:
        logger.error("MalwareBazaar: Timeout (15 san)")
        return []
    except requests.exceptions.ConnectionError:
        logger.error("MalwareBazaar: Bağlantı xətası")
        return []
    except requests.exceptions.HTTPError as e:
        logger.error(f"MalwareBazaar: HTTP {e.response.status_code}")
        return []
    except csv.Error as e:
        logger.error(f"MalwareBazaar: CSV parse xətası: {str(e)}")
        return []
    except Exception as e:
        logger.error(f"MalwareBazaar: Naməlum xəta: {str(e)}")
        return []


def fetch_spamhaus() -> List[Dict[str, Any]]:
    """
    Spamhaus DROP list-indən spam botnet IP-lərini çəkir.
    
    Sadə text formatında IP-ləri qaytarır.
    
    Returns:
        List[Dict]: IOC məlumat siyahısı
        Xəta halında: boş siyahı []
    
    Nümunə çıxışı:
        [
            {"cidr": "192.168.1.0/24", "reason": "SBL12345"},
            ...
        ]
    """
    url = FEED_URLs["spamhaus"]
    iocs = []
    
    try:
        logger.info(f"Spamhaus DROP-dan məlumat çəkilir: {url}")
        
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        }
        response = requests.get(url, headers=headers, timeout=15)
        response.raise_for_status()
        
        lines = response.text.splitlines()
        
        for line in lines:
            line = line.strip()
            
            # Boş sətirləri və tam comment sətirlərini keç
            if not line or line.startswith(";"):
                continue
            
            # Format: "192.168.1.0/24 ; SBL12345" və ya "192.168.1.0/24 ; \"REASON\""
            if ";" in line:
                parts = line.split(";", 1)
                cidr = parts[0].strip()
                reason = parts[1].strip().strip('"') if len(parts) > 1 else ""
            else:
                cidr = line
                reason = ""
            
            if cidr:
                iocs.append({"cidr": cidr, "reason": reason})
        
        logger.info(f"Spamhaus: {len(iocs)} IOC çəkildi")
        return iocs
        
    except requests.exceptions.Timeout:
        logger.error("Spamhaus: Timeout (15 san)")
        return []
    except requests.exceptions.ConnectionError:
        logger.error("Spamhaus: Bağlantı xətası")
        return []
    except requests.exceptions.HTTPError as e:
        logger.error(f"Spamhaus: HTTP {e.response.status_code}")
        return []
    except Exception as e:
        logger.error(f"Spamhaus: Naməlum xəta: {str(e)}")
        return []


def fetch_all_feeds() -> Dict[str, List[Dict[str, Any]]]:
    """
    Bütün feed-lərdən məlumatı ardıcıl şəkildə çəkir.
    
    Hər feed öz funksiyasında artıq xəta-toleranslıdır (try/except),
    ona görə bir feed uğursuz olsa belə digərləri davam edir.
    
    Returns:
        Dict: {feed_name: IOC siyahısı, ...}
        Nümunə: {
            "feodo": [...],
            "urlhaus": [...],
            "malwarebazaar": [...],
            "spamhaus": [...]
        }
    """
    results = {}
    
    fetch_functions = {
        "feodo": fetch_feodo,
        "urlhaus": fetch_urlhaus,
        "malwarebazaar": fetch_malwarebazaar,
        "spamhaus": fetch_spamhaus,
    }
    
    for feed_name, fetch_func in fetch_functions.items():
        try:
            logger.info(f"'{feed_name}' feed-i işlənir...")
            results[feed_name] = fetch_func()
        except Exception as e:
            # Hər fetcher öz daxilində artıq except edir, amma
            # gözlənilməz xətalara qarşı əlavə təhlükəsizlik qatı
            logger.error(f"'{feed_name}' feed-i gözlənilməz xəta ilə uğursuz oldu: {str(e)}")
            results[feed_name] = []
    
    total = sum(len(v) for v in results.values())
    logger.info(f"Bütün feed-lər tamamlandı. Cəmi: {total} IOC")
    
    return results
