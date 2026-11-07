# services/simulator

Kamar dummy (`device_id` = `2`) yang memakai topik dan payload MQTT yang sama dengan ESP32 (PRD US-17). Aplikasi tidak boleh bisa membedakannya dari kamar nyata.

**Pemilik:** belum diputuskan (CONTRACT.md 6.4). **Langkah:** R-04.

Skenario yang wajib bisa dipilih:

| Skenario | Perilaku |
|---|---|
| `normal` | Telemetri tiap 10 dtk dengan pemakaian wajar |
| `leak-continuous` | Aliran tanpa jeda sampai aturan 45 menit terpicu |
| `leak-stable` | Aliran ±10% selama 5 menit |
| `quiet-hours` | Aliran > 1,0 L/menit selama 5 menit di jam sepi |
| `offline` | Berhenti mengirim (uji batas 30 dtk) |
| `no-ack` | Menerima `cmd` tapi tidak membalas `ack` |

Stack: Python, paho-mqtt. Kredensial dari `.env` (`SIM_MQTT_USERNAME`, `SIM_MQTT_PASSWORD`).
