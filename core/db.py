"""
Database Module (SQLite)

IOC məlumatlarını SQLite bazasında saxlamaq, 
deduplication, CRUD əməliyyatları.

Verilənlər Bazası Sxemi:
- ioc_value (TEXT): IP, domain, hash, url
- ioc_type (TEXT): 'ip', 'domain', 'hash', 'url'
- source_feed (TEXT): feed adı
- first_seen (DATETIME): İlk görülme
- last_seen (DATETIME): Son görülme
- confidence_score (INTEGER): 1-100 balla
- tags (TEXT): JSON array
"""

import sqlite3
import logging
import json
from typing import List, Dict, Any, Optional
from datetime import datetime, timezone
import os

from core import scoring

logger = logging.getLogger(__name__)

DB_PATH = "ioc_database.db"


def _get_connection() -> sqlite3.Connection:
    """
    SQLite bağlantısı yaradır və qaytarır.
    
    Row factory sqlite3.Row olaraq təyin olunur ki, sətirlərə
    dict kimi (sütun adı ilə) müraciət edilə bilsin.
    
    Returns:
        sqlite3.Connection: Açıq baza bağlantısı
    """
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_database() -> None:
    """
    SQLite bazasını başlanğıc vəziyyətdə yaradır.
    
    İlk dəfə çalışdırıldıqda cədvəli (table) yaradır.
    İkinci dəfə çalışdırıldıqda heç nə etməz (cədvəl artıq mövcuddur,
    'CREATE TABLE IF NOT EXISTS' istifadə olunur).
    
    Sxem:
        ioc_value (TEXT), ioc_type (TEXT), source_feed (TEXT),
        first_seen (DATETIME), last_seen (DATETIME),
        confidence_score (INTEGER), tags (TEXT)
        UNIQUE(ioc_value, ioc_type) - dedup üçün
    
    Returns:
        None
    """
    try:
        conn = _get_connection()
        cursor = conn.cursor()
        
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS ioc (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                ioc_value TEXT NOT NULL,
                ioc_type TEXT NOT NULL,
                source_feed TEXT NOT NULL,
                first_seen DATETIME NOT NULL,
                last_seen DATETIME NOT NULL,
                confidence_score INTEGER DEFAULT 0,
                tags TEXT DEFAULT '[]',
                UNIQUE(ioc_value, ioc_type)
            )
        """)
        
        # Sürətli axtarış üçün index
        cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_ioc_value_type 
            ON ioc(ioc_value, ioc_type)
        """)
        
        conn.commit()
        conn.close()
        logger.info(f"Verilənlər bazası hazırdır: {DB_PATH}")
        
    except sqlite3.Error as e:
        logger.error(f"Baza yaradılarkən xəta: {str(e)}")
        raise


def _upsert_ioc_with_cursor(cursor: sqlite3.Cursor, ioc: Dict[str, Any]) -> bool:
    """
    insert_ioc()-un əsas dedup+insert/update məntiqi, amma mövcud cursor
    üzərindən işləyir (yeni bağlantı açmır, commit etmir). Bu, insert_ioc()
    və insert_batch() arasında kodu təkrarlamamaq və insert_batch()-da
    minlərlə IOC üçün tək bağlantı istifadə etməyə imkan vermək üçündür
    (hər sətir üçün ayrıca bağlantı açmaq performansı kəskin aşağı salır).

    Args:
        cursor (sqlite3.Cursor): Aktiv baza cursor-u
        ioc (Dict): Normallaşdırılmış IOC məlumatı

    Returns:
        bool: Uğurlu olub-olmadığı (validasiya keçmədisə False)
    """
    required_keys = {"ioc_value", "ioc_type", "source_feed", "first_seen", "last_seen"}
    if not required_keys.issubset(ioc.keys()):
        missing = required_keys - ioc.keys()
        logger.error(f"IOC-da tələb olunan sahələr yoxdur: {missing}")
        return False

    existing = cursor.execute(
        "SELECT id, source_feed FROM ioc WHERE ioc_value = ? AND ioc_type = ?",
        (ioc["ioc_value"], ioc["ioc_type"])
    ).fetchone()

    tags_json = json.dumps(ioc.get("tags", []))

    if existing:
        existing_feeds = set(existing["source_feed"].split(","))
        existing_feeds.add(ioc["source_feed"])
        merged_feeds = ",".join(sorted(existing_feeds))

        new_score = scoring.calculate_score({"source_feed": merged_feeds})

        cursor.execute(
            """UPDATE ioc 
               SET last_seen = ?, source_feed = ?, confidence_score = ? 
               WHERE ioc_value = ? AND ioc_type = ?""",
            (ioc["last_seen"], merged_feeds, new_score, ioc["ioc_value"], ioc["ioc_type"])
        )
        logger.debug(f"IOC yeniləndi (dedup): {ioc['ioc_value']} ({ioc['ioc_type']}), score={new_score}")
    else:
        initial_score = scoring.calculate_score({"source_feed": ioc["source_feed"]})

        cursor.execute(
            """INSERT INTO ioc 
               (ioc_value, ioc_type, source_feed, first_seen, last_seen, 
                confidence_score, tags) 
               VALUES (?, ?, ?, ?, ?, ?, ?)""",
            (ioc["ioc_value"], ioc["ioc_type"], ioc["source_feed"],
             ioc["first_seen"], ioc["last_seen"], initial_score, tags_json)
        )
        logger.debug(f"Yeni IOC əlavə edildi: {ioc['ioc_value']} ({ioc['ioc_type']}), score={initial_score}")

    return True


def insert_ioc(ioc: Dict[str, Any]) -> bool:
    """
    Yeni IOC əlavə edir. Dedup: eyni (ioc_value, ioc_type) varsa 
    qeydləmə etmə, sadəcə last_seen və source_feed yenilə.
    
    Yeni qeyd əlavə edilərkən confidence_score 1 (ilk feed) təyin olunur.
    Mövcud qeyd yenilənərkən (yeni feed-də görünübsə) confidence_score
    core.scoring modulu tərəfindən ayrıca hesablanmalıdır (bax: scoring.py).
    Burada sadəcə last_seen/source_feed yenilənir, score dəyişmir —
    score hesablanması dedup_score axınında ayrıca çağırılır.
    
    Tək IOC üçün nəzərdə tutulub. Çoxlu IOC üçün insert_batch()
    istifadə et (əhəmiyyətli dərəcədə sürətlidir, çünki tək bağlantı
    və tək transaction istifadə edir).
    
    Args:
        ioc (Dict): Normallaşdırılmış IOC məlumatı. Gözlənilən açarlar:
                    ioc_value, ioc_type, source_feed, first_seen, 
                    last_seen, tags (optional)
        
    Returns:
        bool: Uğurlu olub-olmadığı
    """
    try:
        conn = _get_connection()
        cursor = conn.cursor()
        result = _upsert_ioc_with_cursor(cursor, ioc)
        if result:
            conn.commit()
        conn.close()
        return result

    except sqlite3.Error as e:
        logger.error(f"IOC insert xətası: {str(e)}")
        return False


def insert_batch(iocs: List[Dict[str, Any]]) -> int:
    """
    Çoxlu IOC-ları bir sefərdə əlavə edir.
    
    Performans üçün TƏK bağlantı və TƏK transaction istifadə edir
    (hər sətir üçün ayrıca bağlantı açmaq, xüsusən minlərlə IOC-da,
    performansı kəskin aşağı salır — hər sətir üçün ayrıca disk
    sinxronizasiyası tələb edir). Bir IOC-dakı xəta digərlərini
    dayandırmır (loop daxilində tutulur, transaction pozulmur).
    
    Args:
        iocs (List[Dict]): IOC siyahısı
        
    Returns:
        int: Uğurla əlavə edilən (və ya yenilənən) IOC sayı
    """
    if not iocs:
        return 0

    success_count = 0

    try:
        conn = _get_connection()
        cursor = conn.cursor()

        for ioc in iocs:
            try:
                if _upsert_ioc_with_cursor(cursor, ioc):
                    success_count += 1
            except Exception as e:
                logger.error(f"Batch insert-də IOC keçildi: {str(e)}")
                continue

        conn.commit()
        conn.close()

    except sqlite3.Error as e:
        logger.error(f"Batch insert bağlantı xətası: {str(e)}")
        return success_count
    
    logger.info(f"Batch insert: {success_count}/{len(iocs)} IOC emal edildi")
    return success_count


def _row_to_dict(row: sqlite3.Row) -> Dict[str, Any]:
    """
    SQLite Row obyektini dict-ə çevirir, tags sahəsini JSON-dan parse edir.
    
    Args:
        row (sqlite3.Row): Baza sətri
        
    Returns:
        Dict: IOC məlumatı (tags list olaraq)
    """
    result = dict(row)
    try:
        result["tags"] = json.loads(result.get("tags") or "[]")
    except (json.JSONDecodeError, TypeError):
        result["tags"] = []
    return result


def get_ioc(ioc_value: str, ioc_type: str) -> Optional[Dict[str, Any]]:
    """
    Bazadan xüsusi IOC-u sorğu olunur.
    
    Args:
        ioc_value (str): IOC dəyəri (IP, domain, etc)
        ioc_type (str): IOC tipi
        
    Returns:
        Dict: IOC məlumatı (varsa), None (yoxsa)
    """
    try:
        conn = _get_connection()
        cursor = conn.cursor()
        
        row = cursor.execute(
            "SELECT * FROM ioc WHERE ioc_value = ? AND ioc_type = ?",
            (ioc_value, ioc_type)
        ).fetchone()
        
        conn.close()
        
        if row is None:
            return None
        
        return _row_to_dict(row)
        
    except sqlite3.Error as e:
        logger.error(f"IOC sorğu xətası: {str(e)}")
        return None


def get_all_iocs() -> List[Dict[str, Any]]:
    """
    Bazadakı bütün IOC-ları qaytarır.
    
    Returns:
        List[Dict]: Bütün IOC-lar (tags list olaraq parse edilmiş)
    """
    try:
        conn = _get_connection()
        cursor = conn.cursor()
        
        rows = cursor.execute("SELECT * FROM ioc ORDER BY last_seen DESC").fetchall()
        conn.close()
        
        return [_row_to_dict(row) for row in rows]
        
    except sqlite3.Error as e:
        logger.error(f"Bütün IOC-ları sorğu edərkən xəta: {str(e)}")
        return []


def update_ioc(ioc_value: str, ioc_type: str, last_seen: str, 
               source_feed: str) -> bool:
    """
    Mövcud IOC-un son görülmə tarixini və feed-i yeniləyir.
    
    Qeyd: insert_ioc() dedup zamanı bunu avtomatik edir. Bu funksiya
    kənardan (məs: CLI, API) birbaşa yeniləmə lazım olduqda istifadə olunur.
    
    Args:
        ioc_value (str): IOC dəyəri
        ioc_type (str): IOC tipi
        last_seen (str): Yeni son görülmə tarixi (ISO 8601 string)
        source_feed (str): Feed adı
        
    Returns:
        bool: Uğurlu olub-olmadığı (IOC tapılmadısa da False)
    """
    try:
        conn = _get_connection()
        cursor = conn.cursor()
        
        cursor.execute(
            """UPDATE ioc SET last_seen = ?, source_feed = ? 
               WHERE ioc_value = ? AND ioc_type = ?""",
            (last_seen, source_feed, ioc_value, ioc_type)
        )
        
        updated = cursor.rowcount > 0
        conn.commit()
        conn.close()
        
        if not updated:
            logger.warning(f"Yenilənəcək IOC tapılmadı: {ioc_value} ({ioc_type})")
        
        return updated
        
    except sqlite3.Error as e:
        logger.error(f"IOC yeniləmə xətası: {str(e)}")
        return False


def delete_ioc(ioc_value: str, ioc_type: str) -> bool:
    """
    Bazadan IOC-u silir.
    
    Args:
        ioc_value (str): IOC dəyəri
        ioc_type (str): IOC tipi
        
    Returns:
        bool: Uğurlu olub-olmadığı (IOC tapılmadısa da False)
    """
    try:
        conn = _get_connection()
        cursor = conn.cursor()
        
        cursor.execute(
            "DELETE FROM ioc WHERE ioc_value = ? AND ioc_type = ?",
            (ioc_value, ioc_type)
        )
        
        deleted = cursor.rowcount > 0
        conn.commit()
        conn.close()
        
        return deleted
        
    except sqlite3.Error as e:
        logger.error(f"IOC silmə xətası: {str(e)}")
        return False


def get_count() -> int:
    """
    Bazadakı toplam IOC sayını qaytarır.
    
    Returns:
        int: IOC sayı (xəta halında 0)
    """
    try:
        conn = _get_connection()
        cursor = conn.cursor()
        
        row = cursor.execute("SELECT COUNT(*) as cnt FROM ioc").fetchone()
        conn.close()
        
        return row["cnt"] if row else 0
        
    except sqlite3.Error as e:
        logger.error(f"IOC sayı sorğu xətası: {str(e)}")
        return 0


def close_database() -> None:
    """
    Baza əlaqəsini bağlayır.
    
    Qeyd: Bu modul hər funksiyada öz bağlantısını açıb bağladığı 
    üçün (connection-per-call pattern) daimi açıq bağlantı saxlanmır.
    Bu funksiya gələcəkdə connection pool əlavə edilərsə istifadə 
    olunmaq üçün nəzərdə tutulub; hazırda heç bir əməliyyat lazım deyil.
    
    Returns:
        None
    """
    logger.debug("close_database() çağırıldı (connection-per-call pattern, əməliyyat lazım deyil)")
    return None
