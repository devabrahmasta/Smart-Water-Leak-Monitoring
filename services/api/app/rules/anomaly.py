"""
Fungsi murni evaluasi anomali pemakaian air harian di server (US-16).
Aturan:
- Membandingkan pemakaian hari ini terhadap rata-rata riwayat (default: 7 hari sebelumnya).
- Anomali jika: pemakaian hari ini > 1.5x rata-rata historis.
- Membutuhkan minimal 3 hari data historis sebelum aturan aktif.
"""

from typing import List, Tuple, Optional


def evaluate_daily_anomaly(
    today_volume: float,
    history_volumes: List[float],
    ratio_threshold: float = 1.5,
    min_history_days: int = 3,
) -> Tuple[bool, Optional[float], Optional[float]]:
    """
    Mengevaluasi apakah pemakaian hari ini tergolong anomali (fungsi murni tanpa efek samping).
    Mengembalikan tuple: (is_anomaly, ratio, avg_daily_l).
    Jika data riwayat kurang dari min_history_days, mengembalikan (False, None, None).
    """
    if len(history_volumes) < min_history_days:
        return False, None, None

    avg_daily = sum(history_volumes) / len(history_volumes)
    if avg_daily <= 0.0:
        return False, 0.0, 0.0

    ratio = today_volume / avg_daily
    is_anomaly = ratio > ratio_threshold

    return is_anomaly, round(ratio, 2), round(avg_daily, 2)

