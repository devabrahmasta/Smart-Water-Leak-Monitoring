"""
Seeding script untuk Smart Water Database (R-02).

Menginisialisasi:
1. 2 Kamar (Kamar 1 fisik, Kamar 2 simulator) beserta relasi perangkatnya (device '1' dan '2').
2. Parameter default rule_params (9 ambang deteksi kebocoran dan anomali).

Fungsi ini bersifat idempotent: aman dijalankan berulang kali.
"""

from typing import Dict, Any, List
from sqlalchemy.orm import Session

from app.database import SessionLocal
from app.models.room import Room
from app.models.device import Device, ValveState
from app.models.rule_param import RuleParam

DEFAULT_ROOMS: List[Dict[str, Any]] = [
    {
        "name": "Kamar 1",
        "sort_order": 1,
        "is_simulated": False,
        "device_id": "1",
    },
    {
        "name": "Kamar 2",
        "sort_order": 2,
        "is_simulated": True,
        "device_id": "2",
    },
]

DEFAULT_RULE_PARAMS: List[Dict[str, str]] = [
    {
        "key": "leak_duration_min",
        "value": "45",
        "description": "Durasi aliran kontinu sebelum dianggap bocor (menit)",
    },
    {
        "key": "stable_duration_min",
        "value": "5",
        "description": "Durasi aliran debit stabil (menit)",
    },
    {
        "key": "stable_variation_pct",
        "value": "10",
        "description": "Variasi batas debit stabil (+/- persen)",
    },
    {
        "key": "night_flow_threshold_lpm",
        "value": "1.0",
        "description": "Ambang batas debit aliran pada jam sepi (L/menit)",
    },
    {
        "key": "night_duration_min",
        "value": "5",
        "description": "Durasi aliran jam sepi sebelum dianggap bocor (menit)",
    },
    {
        "key": "quiet_start",
        "value": "01:00",
        "description": "Waktu mulai jam sepi (WIB)",
    },
    {
        "key": "quiet_end",
        "value": "04:00",
        "description": "Waktu selesai jam sepi (WIB)",
    },
    {
        "key": "anomaly_ratio",
        "value": "1.5",
        "description": "Rasio pemakaian harian vs rata-rata historis untuk memicu anomali",
    },
    {
        "key": "anomaly_window_days",
        "value": "7",
        "description": "Jendela hari historis pembanding deteksi anomali",
    },
]


def seed_database(db: Session) -> None:
    """Melakukan seeding awal kamar, perangkat, dan parameter aturan secara idempotent."""
    # 1. Seed Rooms & Devices
    for item in DEFAULT_ROOMS:
        room = db.query(Room).filter(Room.name == item["name"]).first()
        if not room:
            room = Room(
                name=item["name"],
                sort_order=item["sort_order"],
                is_simulated=item["is_simulated"],
            )
            db.add(room)
            db.flush()

        device = db.query(Device).filter(Device.id == item["device_id"]).first()
        if not device:
            device = Device(
                id=item["device_id"],
                room_id=room.id,
                valve_state=ValveState.OPEN,
            )
            db.add(device)
        else:
            device.room_id = room.id

    # 2. Seed Rule Params
    for param_data in DEFAULT_RULE_PARAMS:
        param = db.query(RuleParam).filter(RuleParam.key == param_data["key"]).first()
        if not param:
            param = RuleParam(
                key=param_data["key"],
                value=param_data["value"],
                description=param_data.get("description"),
            )
            db.add(param)
        else:
            param.description = param_data.get("description")

    db.commit()


if __name__ == "__main__":
    db = SessionLocal()
    try:
        seed_database(db)
        print("Database seed completed successfully.")
    finally:
        db.close()

