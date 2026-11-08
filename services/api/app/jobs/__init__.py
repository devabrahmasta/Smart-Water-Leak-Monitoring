"""
Modul Background Jobs dan Scheduler untuk Smart Water Monitoring.
"""

from app.jobs.aggregation import aggregate_daily_usage, aggregate_monthly_usage
from app.jobs.anomaly import run_anomaly_detection
from app.jobs.offline import check_offline_devices
from app.jobs.timeouts import expire_stale_commands
from app.jobs.scheduler import start_scheduler, stop_scheduler, scheduler

__all__ = [
    "aggregate_daily_usage",
    "aggregate_monthly_usage",
    "run_anomaly_detection",
    "check_offline_devices",
    "expire_stale_commands",
    "start_scheduler",
    "stop_scheduler",
    "scheduler",
]

