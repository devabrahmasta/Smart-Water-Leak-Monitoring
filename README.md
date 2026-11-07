# Smart Water

Pemantauan dan kendali air per kamar kos, dengan penutupan valve otomatis saat bocor.
Proyek Praktikum IoT, Tim Timun Mania. Demo: 15 November 2026.

- Kebutuhan produk: [docs/PRD.md](docs/PRD.md)
- Kontrak antarbagian (MQTT, REST, FCM): [docs/CONTRACT.md](docs/CONTRACT.md)
- Aturan untuk *coding agent*: [AGENTS.md](AGENTS.md)

## Struktur

```
.
├── AGENTS.md             aturan untuk coding agent
├── docs/                 PRD, kontrak, DESIGN.md, catatan keputusan (ADR)
├── packages/contracts/   openapi.json, JSON Schema MQTT, fixtures
├── apps/mobile/          aplikasi Flutter (Android)
├── services/api/         FastAPI + worker MQTT + APScheduler
├── services/simulator/   kamar dummy (Python)
├── firmware/esp32/       sketch ESP32
└── infra/                docker-compose (Postgres + Mosquitto TLS)
```

## Pembagian kerja

| Jalur | Folder | Pemilik | Langkah PRD |
|---|---|---|---|
| Backend | `services/api`, `infra`, `packages/contracts` | _(isi nama)_ | R-00 s.d. R-03, R-05 s.d. R-08 |
| Mobile | `apps/mobile` | _(isi nama)_ | R-09 s.d. R-12 |
| Firmware & hardware | `firmware/esp32`, rangkaian | _(isi nama)_, _(isi nama)_ | R-13 |
| Simulator | `services/simulator` | _(belum diputuskan, lihat CONTRACT.md 6.4)_ | R-04 |

Tiap folder punya `README.md` berisi apa yang dikerjakan di sana dan cara memulainya.

## Alur kerja Git

1. Jangan commit langsung ke `main`. Buat cabang per langkah: `r05-valve-command`, `mobile/r10-components`.
2. Buka Pull Request. Satu anggota lain membaca *diff* sebelum *merge*.
3. Perubahan kontrak (`docs/CONTRACT.md`, `packages/contracts`) wajib disetujui semua jalur yang terdampak.
4. Rahasia hanya di `.env` dan `firmware/esp32/secrets.h`, keduanya sudah di `.gitignore`.

## Menjalankan lokal

```bash
cp .env.example .env      # lalu isi nilainya
make dev                  # Postgres + Mosquitto
```

Cara menjalankan backend, mobile, simulator, dan firmware ada di README masing-masing folder.
