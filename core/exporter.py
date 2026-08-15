"""
Exporter Module

IOC məlumatlarını CSV və JSON formatında export edir.

Çıxış Faylları (default olaraq sample_output/ qovluğuna yazılır):
- ioc_export.csv
- ioc_export.json
"""

import logging
import json
import csv
import os
from typing import List, Dict, Any

logger = logging.getLogger(__name__)

EXPORT_DIR = "sample_output"

# CSV sütun sırası (verilənlər bazası sxemi ilə uyğun)
CSV_FIELDNAMES = [
    "ioc_value", "ioc_type", "source_feed",
    "first_seen", "last_seen", "confidence_score", "tags",
]


def _ensure_export_dir() -> None:
    """
    EXPORT_DIR qovluğunun mövcud olduğundan əmin olur, yoxdursa yaradır.
    
    Returns:
        None
    """
    os.makedirs(EXPORT_DIR, exist_ok=True)


def export_to_csv(iocs: List[Dict[str, Any]], filename: str = "ioc_export.csv") -> bool:
    """
    IOC məlumatlarını CSV faylına export edir.
    
    'tags' sahəsi (list) CSV-də sətir kimi saxlanmaq üçün JSON string-ə 
    çevrilir. Boş siyahı verilsə belə, yalnız başlıq sətri olan fayl yaradılır.
    
    Args:
        iocs (List[Dict]): IOC siyahısı
        filename (str): Çıxış fayl adı
        
    Returns:
        bool: Uğurlu olub-olmadığı
    """
    try:
        _ensure_export_dir()
        filepath = os.path.join(EXPORT_DIR, filename)
        
        with open(filepath, "w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=CSV_FIELDNAMES, extrasaction="ignore")
            writer.writeheader()
            
            for ioc in iocs:
                row = dict(ioc)
                # tags list-dirsə JSON string-ə çevir ki, CSV-də bir xanaya sığsın
                if isinstance(row.get("tags"), (list, dict)):
                    row["tags"] = json.dumps(row["tags"], ensure_ascii=False)
                writer.writerow(row)
        
        logger.info(f"CSV export tamamlandı: {filepath} ({len(iocs)} IOC)")
        return True
        
    except (OSError, csv.Error) as e:
        logger.error(f"CSV export xətası: {str(e)}")
        return False
    except Exception as e:
        logger.error(f"CSV export gözlənilməz xəta: {str(e)}")
        return False


def export_to_json(iocs: List[Dict[str, Any]], filename: str = "ioc_export.json") -> bool:
    """
    IOC məlumatlarını JSON faylına export edir.
    
    Insan tərəfindən oxuna bilən formatda (indent=2), UTF-8 dəstəyi ilə 
    (ensure_ascii=False) yazır ki, Azərbaycan hərfləri düzgün görünsün.
    
    Args:
        iocs (List[Dict]): IOC siyahısı
        filename (str): Çıxış fayl adı
        
    Returns:
        bool: Uğurlu olub-olmadığı
    """
    try:
        _ensure_export_dir()
        filepath = os.path.join(EXPORT_DIR, filename)
        
        with open(filepath, "w", encoding="utf-8") as f:
            json.dump(iocs, f, indent=2, ensure_ascii=False, default=str)
        
        logger.info(f"JSON export tamamlandı: {filepath} ({len(iocs)} IOC)")
        return True
        
    except (OSError, TypeError) as e:
        logger.error(f"JSON export xətası: {str(e)}")
        return False
    except Exception as e:
        logger.error(f"JSON export gözlənilməz xəta: {str(e)}")
        return False


def export_both(iocs: List[Dict[str, Any]]) -> bool:
    """
    IOC məlumatlarını həm CSV, həm JSON formatında export edir.
    
    Hər iki export ayrı-ayrı cəhd edilir; biri uğursuz olsa belə 
    digəri yenə də sınanır (xəta bir-birinə mane olmur).
    
    Args:
        iocs (List[Dict]): IOC siyahısı
        
    Returns:
        bool: Hər iki export də uğurlu olduqda True, əks halda False
    """
    csv_ok = export_to_csv(iocs)
    json_ok = export_to_json(iocs)
    
    if not csv_ok:
        logger.error("export_both: CSV export uğursuz oldu")
    if not json_ok:
        logger.error("export_both: JSON export uğursuz oldu")
    
    return csv_ok and json_ok
