"""
Confidence Scoring Module

IOC-lara etibarınlıq balla verir.

Scoring Məntiqi (sadə say məntiqi):
- IOC-un source_feed sahəsi vergüllə ayrılmış feed adlarını saxlayır
  (bax: core/db.py insert_ioc() dedup birləşdirmə məntiqi)
- Neçə fərqli feed-də görünübsə, bal bir o qədər yüksəkdir:
  1 feed  -> 25 bal
  2 feed  -> 50 bal
  3 feed  -> 75 bal
  4 feed  -> 100 bal
- Ümumi düstur: min(100, feed_sayı * 25)
"""

import logging
from typing import Dict, Any, List

logger = logging.getLogger(__name__)

# Hər fərqli feed üçün əlavə olunan bal
SCORE_PER_FEED = 25
MAX_SCORE = 100


def calculate_score(ioc: Dict[str, Any]) -> int:
    """
    Tək IOC üçün confidence score hesablayır.
    
    IOC-un 'source_feed' sahəsindəki (vergüllə ayrılmış) fərqli 
    feed sayına əsasən hesablanır. Sahə boşdursa və ya yoxdursa, 0 qaytarılır.
    
    Args:
        ioc (Dict): IOC məlumatı ('source_feed' açarı gözlənilir,
                    məs: "feodo,urlhaus" və ya sadəcə "feodo")
        
    Returns:
        int: Confidence score (0-100 aralığında)
    """
    source_feed = ioc.get("source_feed", "")
    
    if not source_feed:
        logger.warning("IOC-da 'source_feed' sahəsi yoxdur, score 0 təyin edilir")
        return 0
    
    # Vergüllə ayrılmış fərqli feed adlarını say
    feed_names = {f.strip() for f in source_feed.split(",") if f.strip()}
    feed_count = len(feed_names)
    
    score = min(MAX_SCORE, feed_count * SCORE_PER_FEED)
    return score


def update_scores_batch(iocs: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    Çoxlu IOC-lar üçün score-u yeniləyir.
    
    Hər IOC-un 'confidence_score' sahəsini calculate_score() nəticəsi 
    ilə əvəz edir. Orijinal siyahını dəyişdirmir, yeni siyahı qaytarır.
    
    Args:
        iocs (List[Dict]): IOC siyahısı
        
    Returns:
        List[Dict]: confidence_score sahəsi yenilənmiş IOC siyahısı
    """
    updated = []
    
    for ioc in iocs:
        try:
            new_ioc = dict(ioc)
            new_ioc["confidence_score"] = calculate_score(ioc)
            updated.append(new_ioc)
        except Exception as e:
            logger.error(f"Score hesablanarkən xəta (IOC dəyişməz saxlanıldı): {str(e)}")
            updated.append(ioc)
    
    return updated
