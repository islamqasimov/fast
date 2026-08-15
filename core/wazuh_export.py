"""
Wazuh CDB List Exporter Module

Bazadakı IOC-ları Wazuh-un CDB (Constant Database) list formatına
çevirir. Bu format Wazuh Manager-in <list> qaydalarında istifadə olunur
(bax: infra/ansible/roles/wazuh-manager/templates/ioc_rules.xml.j2).

CDB List Format:
    <dəyər>:<istənilən_dəyər>

    Nümunə:
        1.2.3.4:1
        5.6.7.8:1

Wazuh yalnız `:` işarəsindən əvvəlki hissəni açar kimi istifadə edir,
sonrakı hissə formal tələbdir (adətən "1" yazılır).

Qeyd: Wazuh CDB list-ləri IP-lər üçün nəzərdə tutulub (srcip/dstip
sahələrində lookup edilir). Ona görə yalnız ioc_type == "ip" olan
qeydlər export olunur; hash/url/domain fərqli detection mexanizmi
tələb edir (gələcək inkişaf: FIM/YARA inteqrasiyası).
"""

import logging
import os
from typing import List, Dict, Any

logger = logging.getLogger(__name__)

DEFAULT_CDB_FILENAME = "ioc-ips"


def _extract_ip_value(ioc_value: str) -> str:
    """
    IOC dəyərindən Wazuh CDB list üçün uyğun IP/CIDR string-i çıxarır.

    Spamhaus kimi mənbələr CIDR formatında (məs: "192.168.1.0/24")
    gələ bilər. Wazuh CDB list-i həm tək IP, həm CIDR qəbul edir,
    ona görə dəyər olduğu kimi saxlanılır.

    Args:
        ioc_value (str): IOC dəyəri (IP və ya CIDR)

    Returns:
        str: Wazuh CDB list-ə yazılacaq dəyər
    """
    return ioc_value.strip()


def export_to_cdb_list(
    iocs: List[Dict[str, Any]],
    output_dir: str = "sample_output",
    filename: str = DEFAULT_CDB_FILENAME,
    min_confidence: int = 0,
) -> bool:
    """
    IOC siyahısındakı 'ip' tipli qeydləri Wazuh CDB list faylına yazır.

    Yalnız ioc_type == "ip" olan qeydlər daxil edilir. min_confidence
    parametri ilə aşağı etibarlılıqlı (məs. yalnız 1 feed-də görünən)
    IOC-ları süzgəcdən keçirmək mümkündür ki, false-positive riski azalsın.

    Args:
        iocs (List[Dict]): Verilənlər bazasından gələn IOC siyahısı
                            (get_all_iocs() formatında)
        output_dir (str): Çıxış qovluğu
        filename (str): Çıxış fayl adı (uzantısız, Wazuh CDB konvensiyası)
        min_confidence (int): Minimum confidence_score astanası (default: 0, hamısı)

    Returns:
        bool: Uğurlu olub-olmadığı
    """
    try:
        ip_iocs = [
            ioc for ioc in iocs
            if ioc.get("ioc_type") == "ip" and ioc.get("confidence_score", 0) >= min_confidence
        ]

        if not ip_iocs:
            logger.warning(
                f"CDB export: min_confidence={min_confidence} şərtini ödəyən 'ip' tipli IOC tapılmadı"
            )

        os.makedirs(output_dir, exist_ok=True)
        filepath = os.path.join(output_dir, filename)

        # Dublikatların qarşısını al (eyni IP iki dəfə yazılmasın)
        seen = set()
        lines = []
        for ioc in ip_iocs:
            value = _extract_ip_value(ioc["ioc_value"])
            if value and value not in seen:
                seen.add(value)
                lines.append(f"{value}:1")

        with open(filepath, "w", encoding="utf-8") as f:
            f.write("\n".join(lines))
            if lines:
                f.write("\n")

        logger.info(f"Wazuh CDB list export tamamlandı: {filepath} ({len(lines)} unikal IP)")
        return True

    except (OSError, TypeError, KeyError) as e:
        logger.error(f"Wazuh CDB export xətası: {str(e)}")
        return False
    except Exception as e:
        logger.error(f"Wazuh CDB export gözlənilməz xəta: {str(e)}")
        return False


def get_export_stats(iocs: List[Dict[str, Any]], min_confidence: int = 0) -> Dict[str, int]:
    """
    CDB export-a daxil olacaq/olmayacaq IOC-ların statistikasını qaytarır.

    CLI-da və ya loglarda "nə qədəri export olunur" məlumatını göstərmək üçün.

    Args:
        iocs (List[Dict]): IOC siyahısı
        min_confidence (int): Minimum confidence_score astanası

    Returns:
        Dict: {"total": int, "ip_type": int, "exported": int, "filtered_out": int}
    """
    total = len(iocs)
    ip_type = sum(1 for ioc in iocs if ioc.get("ioc_type") == "ip")
    exported = sum(
        1 for ioc in iocs
        if ioc.get("ioc_type") == "ip" and ioc.get("confidence_score", 0) >= min_confidence
    )

    return {
        "total": total,
        "ip_type": ip_type,
        "exported": exported,
        "filtered_out": ip_type - exported,
    }
