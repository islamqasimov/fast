"""
IOC Normalizer Module

Müxtəlif feed-lərdən gələn məlumatları vahid sxemə çevirə.

Çıxış Sxemi (Standart Format):
{
    'ioc_value': str,           # IP, domain, hash, url
    'ioc_type': str,            # 'ip', 'domain', 'hash', 'url'
    'source_feed': str,         # 'feodo', 'urlhaus', vb.
    'first_seen': datetime,     # İlk görülme tarixi
    'last_seen': datetime,      # Son görülme tarixi
    'tags': list,               # Əlaqədar tags
}
"""

import logging
from typing import Dict, List, Any, Optional
from datetime import datetime, timezone

logger = logging.getLogger(__name__)


def _parse_date(value: Optional[str]) -> str:
    """
    Müxtəlif tarix formatlarını ISO 8601 string-ə çevirir.
    
    Parse edilə bilmirsə, cari vaxtı (UTC) qaytarır ki, sistem 
    heç vaxt tarixsiz IOC saxlamasın.
    
    Args:
        value (str): Xam tarix string-i (müxtəlif formatlarda ola bilər)
        
    Returns:
        str: ISO 8601 formatında tarix (məs: "2024-01-15T10:30:00")
    """
    if not value:
        return datetime.now(timezone.utc).isoformat()
    
    value = value.strip()
    
    # Sınanacaq formatlar (feed-lərə görə)
    formats = [
        "%Y-%m-%d %H:%M:%S",   # "2024-01-15 10:30:00" (URLhaus, MalwareBazaar)
        "%Y-%m-%d",             # "2024-01-15" (Feodo last_dns_query)
        "%Y-%m-%dT%H:%M:%S",   # ISO format
    ]
    
    for fmt in formats:
        try:
            return datetime.strptime(value, fmt).isoformat()
        except ValueError:
            continue
    
    logger.warning(f"Tarix parse edilə bilmədi: '{value}', cari vaxt istifadə olunur")
    return datetime.now(timezone.utc).isoformat()


def _classify_ip_or_cidr(value: str) -> str:
    """
    Dəyərin sadə IP, yoxsa CIDR bloku olduğunu müəyyən edir.
    Hər ikisi 'ip' tipi kimi saxlanılır (CIDR də IP-based IOC-dur).
    
    Args:
        value (str): IP və ya CIDR string-i
        
    Returns:
        str: "ip"
    """
    return "ip"


def normalize_feodo(raw_iocs: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    Feodo Tracker-dən gələn JSON-u standart formata çevirir.
    
    Feodo IP-lərini 'ip' tipi olaraq map edir, botnet adını tag kimi saxlayır.
    
    Args:
        raw_iocs (List[Dict]): Raw Feodo məlumatı (ip_address, botnet, 
                                last_dns_query sahələri gözlənilir)
        
    Returns:
        List[Dict]: Normallaşdırılmış IOC siyahısı
    """
    normalized = []
    
    for raw in raw_iocs:
        try:
            ip_address = raw.get("ip_address")
            if not ip_address:
                logger.warning("Feodo: 'ip_address' sahəsi olmayan qeyd keçildi")
                continue
            
            tags = []
            if raw.get("botnet"):
                tags.append(str(raw["botnet"]))
            if raw.get("malware"):
                tags.append(str(raw["malware"]))
            
            last_seen = _parse_date(raw.get("last_dns_query") or raw.get("last_online"))
            
            normalized.append({
                "ioc_value": ip_address,
                "ioc_type": "ip",
                "source_feed": "feodo",
                "first_seen": last_seen,
                "last_seen": last_seen,
                "tags": tags,
            })
        except Exception as e:
            logger.error(f"Feodo normalize xətası (qeyd keçildi): {str(e)}")
            continue
    
    logger.info(f"Feodo: {len(normalized)}/{len(raw_iocs)} IOC normallaşdırıldı")
    return normalized


def normalize_urlhaus(raw_iocs: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    URLhaus-dan gələn CSV-ni standart formata çevirir.
    
    URL-ləri 'url' tipi olaraq map edir, threat növünü tag kimi saxlayır.
    
    Args:
        raw_iocs (List[Dict]): Raw URLhaus məlumatı (url, dateadded, 
                                threat, tags sahələri gözlənilir)
        
    Returns:
        List[Dict]: Normallaşdırılmış IOC siyahısı
    """
    normalized = []
    
    for raw in raw_iocs:
        try:
            url_value = raw.get("url")
            if not url_value:
                logger.warning("URLhaus: 'url' sahəsi olmayan qeyd keçildi")
                continue
            
            tags = []
            if raw.get("threat"):
                tags.append(str(raw["threat"]))
            if raw.get("tags"):
                # URLhaus tags "exe,trojan" formatında ola bilər
                tags.extend([t.strip() for t in str(raw["tags"]).split(",") if t.strip()])
            
            date_added = _parse_date(raw.get("dateadded"))
            
            normalized.append({
                "ioc_value": url_value,
                "ioc_type": "url",
                "source_feed": "urlhaus",
                "first_seen": date_added,
                "last_seen": date_added,
                "tags": tags,
            })
        except Exception as e:
            logger.error(f"URLhaus normalize xətası (qeyd keçildi): {str(e)}")
            continue
    
    logger.info(f"URLhaus: {len(normalized)}/{len(raw_iocs)} IOC normallaşdırıldı")
    return normalized


def normalize_malwarebazaar(raw_iocs: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    MalwareBazaar-dan gələn CSV-ni standart formata çevirir.
    
    Hash-ləri 'hash' tipi olaraq map edir. SHA256 üstünlük təşkil edir,
    yoxdursa MD5 istifadə olunur. Fayl adı və siqnatura tag kimi saxlanılır.
    
    Args:
        raw_iocs (List[Dict]): Raw MalwareBazaar məlumatı (sha256_hash, 
                                md5_hash, first_seen_utc, file_name, 
                                signature sahələri gözlənilir)
        
    Returns:
        List[Dict]: Normallaşdırılmış IOC siyahısı
    """
    normalized = []
    
    for raw in raw_iocs:
        try:
            hash_value = raw.get("sha256_hash") or raw.get("md5_hash")
            if not hash_value:
                logger.warning("MalwareBazaar: hash sahəsi olmayan qeyd keçildi")
                continue
            
            tags = []
            if raw.get("signature"):
                tags.append(str(raw["signature"]))
            if raw.get("file_name"):
                tags.append(str(raw["file_name"]))
            if raw.get("file_type_guess"):
                tags.append(str(raw["file_type_guess"]))
            
            first_seen = _parse_date(raw.get("first_seen_utc"))
            
            normalized.append({
                "ioc_value": hash_value,
                "ioc_type": "hash",
                "source_feed": "malwarebazaar",
                "first_seen": first_seen,
                "last_seen": first_seen,
                "tags": tags,
            })
        except Exception as e:
            logger.error(f"MalwareBazaar normalize xətası (qeyd keçildi): {str(e)}")
            continue
    
    logger.info(f"MalwareBazaar: {len(normalized)}/{len(raw_iocs)} IOC normallaşdırıldı")
    return normalized


def normalize_spamhaus(raw_iocs: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    Spamhaus-dan gələn text məlumatı standart formata çevirir.
    
    CIDR/IP-ləri 'ip' tipi olaraq map edir. Spamhaus tarix vermədiyi
    üçün cari vaxt first_seen/last_seen kimi istifadə olunur.
    
    Args:
        raw_iocs (List[Dict]): Raw Spamhaus məlumatı (cidr, reason 
                                sahələri gözlənilir)
        
    Returns:
        List[Dict]: Normallaşdırılmış IOC siyahısı
    """
    normalized = []
    now = datetime.now(timezone.utc).isoformat()
    
    for raw in raw_iocs:
        try:
            cidr_value = raw.get("cidr")
            if not cidr_value:
                logger.warning("Spamhaus: 'cidr' sahəsi olmayan qeyd keçildi")
                continue
            
            tags = []
            if raw.get("reason"):
                tags.append(str(raw["reason"]))
            
            normalized.append({
                "ioc_value": cidr_value,
                "ioc_type": "ip",
                "source_feed": "spamhaus",
                "first_seen": now,
                "last_seen": now,
                "tags": tags,
            })
        except Exception as e:
            logger.error(f"Spamhaus normalize xətası (qeyd keçildi): {str(e)}")
            continue
    
    logger.info(f"Spamhaus: {len(normalized)}/{len(raw_iocs)} IOC normallaşdırıldı")
    return normalized


def normalize_all(raw_feeds: Dict[str, List[Dict[str, Any]]]) -> List[Dict[str, Any]]:
    """
    Bütün feed-lərdən gələn məlumatı normallaşdırır.
    
    Hər feed öz normalizer funksiyasına yönləndirilir. Naməlum feed 
    adı və ya normalize xətası halında o feed skip edilir, digərləri
    ilə davam edilir (crash olmur).
    
    Args:
        raw_feeds (Dict): {feed_name: raw_iocs, ...}
                           Nümunə: {"feodo": [...], "urlhaus": [...]}
        
    Returns:
        List[Dict]: Bütün normallaşdırılmış IOC-lar (bir siyahıda birləşdirilmiş)
    """
    normalize_functions = {
        "feodo": normalize_feodo,
        "urlhaus": normalize_urlhaus,
        "malwarebazaar": normalize_malwarebazaar,
        "spamhaus": normalize_spamhaus,
    }
    
    all_normalized = []
    
    for feed_name, raw_iocs in raw_feeds.items():
        normalize_func = normalize_functions.get(feed_name)
        
        if normalize_func is None:
            logger.warning(f"Naməlum feed adı: '{feed_name}', keçildi")
            continue
        
        try:
            normalized = normalize_func(raw_iocs)
            all_normalized.extend(normalized)
        except Exception as e:
            logger.error(f"'{feed_name}' normalize edilərkən xəta: {str(e)}")
            continue
    
    logger.info(f"Cəmi {len(all_normalized)} IOC normallaşdırıldı ({len(raw_feeds)} feed-dən)")
    return all_normalized
