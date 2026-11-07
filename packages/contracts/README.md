# packages/contracts

Bentuk mesin dari [docs/CONTRACT.md](../../docs/CONTRACT.md). Dipakai bersama oleh backend, mobile, firmware, dan simulator.

**Pemilik:** Backend (CONTRACT.md bagian 0). Jalur lain hanya membaca.

| Berkas | Isi | Langkah |
|---|---|---|
| `mqtt-device.md` | Topik dan payload MQTT | R-01 |
| `schemas/*.json` | JSON Schema untuk 5 payload: telemetry, alert, status, cmd, ack | R-01 |
| `fixtures/*.json` | Contoh payload MQTT dan respons REST untuk tes | R-01, R-07 |
| `openapi.json` | Diekspor dari FastAPI lewat `make contracts`, di-commit | R-07 |

Aturan: setiap fixture lolos validasi skemanya lewat satu tes. Perubahan di sini lewat PR dan disetujui jalur terdampak.
