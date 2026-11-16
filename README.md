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

## Menjalankan dari nol sampai aplikasi di HP

Langkah ini untuk Windows dengan PowerShell. Jalankan dari root proyek, kecuali disebut lain. Langkah 1 sampai 6 cukup sekali.

### 1. Siapkan alat

- [Docker Desktop](https://www.docker.com/products/docker-desktop/), lalu nyalakan
- Python 3.12 atau lebih baru
- [Flutter](https://docs.flutter.dev/get-started/install) dan Git for Windows (untuk OpenSSL)
- HP Android dengan USB debugging aktif
- Arduino IDE dengan board `esp32`, library `PubSubClient` dan `ArduinoJson` (kalau memakai ESP32)
- Sisa ruang disk minimal 10 GB

Laptop, HP, dan ESP32 harus di jaringan Wi-Fi yang sama. ESP32 hanya bisa memakai 2,4 GHz.

### 2. Isi `.env`

```powershell
Copy-Item .env.example .env
```

Isi seperti ini. Nilai berikut hanya untuk pengembangan lokal, dan semua baris wajib terisi:

```ini
POSTGRES_USER=smartwater
POSTGRES_PASSWORD=smartwater_secret
POSTGRES_DB=smartwater
POSTGRES_PORT=5433
DATABASE_URL=postgresql+psycopg://smartwater:smartwater_secret@localhost:5433/smartwater

MQTT_HOST=localhost
MQTT_PORT=8883
MQTT_USERNAME=backend
MQTT_PASSWORD=backend_dev_pass
MQTT_CA_CERT=infra/mosquitto/certs/ca.crt

API_OWNER_TOKEN=isi-token-bebas
API_PORT=8000
TZ_DISPLAY=Asia/Jakarta

# Path absolut. Tanpa file ini, backend tidak benar-benar mengirim push.
FCM_PROJECT_ID=id-project-firebase
FCM_SERVICE_ACCOUNT_PATH=C:/path/ke/proyek/services/api/service-account.json

SIM_DEVICE_ID=2
SIM_MQTT_USERNAME=2
SIM_MQTT_PASSWORD=sim_dev_pass
```

### 3. Buat sertifikat broker

Cari IP Wi-Fi laptop dengan `ipconfig`. Di `infra/setup-certs.ps1`, tambahkan IP itu pada bagian `[alt_names]`, tapi jangan di-commit:

```ini
IP.3 = 192.168.1.114
DNS.3 = 192.168.1.114
```

Lalu jalankan:

```powershell
powershell -ExecutionPolicy Bypass -File infra\setup-certs.ps1
```

Ulangi langkah ini kalau IP laptop berubah, lalu perbarui `secrets.h` di langkah 7.

### 4. Siapkan backend

```powershell
docker compose -f infra\docker-compose.yml --env-file .env up -d
cd services\api
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
alembic upgrade head
python -m app.seed
cd ..\..
```

### 5. Buka firewall

Buka PowerShell dengan **Run as administrator**, lalu jalankan:

```powershell
New-NetFirewallRule -DisplayName "Smart Water API 8000" -Direction Inbound -Protocol TCP -LocalPort 8000 -Action Allow -Profile Private
New-NetFirewallRule -DisplayName "Mosquitto 8883" -Direction Inbound -Protocol TCP -LocalPort 8883 -Action Allow -Profile Private
```

Pastikan jaringan Wi-Fi laptop bertipe **Private**: Settings → Network & internet → Wi-Fi → properti jaringan.

### 6. Siapkan aplikasi

```powershell
cd apps\mobile
flutter pub get
cd ..\..
```

Push FCM opsional. Untuk mengaktifkannya, daftarkan aplikasi Android `id.timunmania.smart_water` di Firebase Console, lalu isi `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_SENDER_ID`, dan `FIREBASE_PROJECT_ID` di `.env`. Tanpa itu aplikasi tetap jalan, dan notifikasi dari Mode demo tetap bisa dicoba.

### 7. Siapkan ESP32 (Kamar 1)

Lewati langkah ini kalau hanya memakai simulator.

1. Salin `firmware/esp32/secrets.example.h` menjadi `firmware/esp32/secrets.h`. Jangan isi file example, karena file itu ikut di-commit.
2. Isi `secrets.h`:
   - `WIFI_SSID`, `WIFI_PASSWORD`: Wi-Fi 2,4 GHz
   - `MQTT_HOST`: IP laptop
   - `MQTT_DEVICE_ID` dan `MQTT_USERNAME`: `1`
   - `MQTT_PASSWORD`: `device1_dev_pass`
   - `MQTT_CA_CERT`: isi file `infra/mosquitto/certs/ca.crt`
3. Buka `firmware/esp32/esp32.ino`, pilih board **ESP32 Dev Module** dan port COM-nya, lalu klik **Upload**.

### 8. Nyalakan semuanya

Mulai dari sini diulang setiap kali memakai. Nyalakan Docker Desktop, lalu:

```powershell
.\start-dev.ps1
```

Terbuka 3 jendela: API, Worker, dan Simulator. Biarkan semuanya terbuka. Cek `http://localhost:8000/health`, hasilnya harus `{"status":"ok"}`.

### 9. Jalankan aplikasi

Colok HP lewat USB, lalu:

```powershell
cd apps\mobile
.\run-backend.ps1
```

Kalau backend ada di laptop lain, pakai `.\run-backend.ps1 -Ip <IP-laptop> -Token <API_OWNER_TOKEN>`.

### 10. Cek hasilnya

| Yang dicek | Hasil yang benar |
|---|---|
| Beranda | Kamar 2 Normal, liter naik |
| Kamar 1 | Normal kalau ESP32 tersambung, Offline kalau belum. Log: `docker logs -f infra-mosquitto-1`, cari `ESP32_SWM_1` |
| Ikon tabung → Mode demo → Bocor | Kamar 2 bocor dalam ±10 detik, Beranda merah |
| Detail Kamar → Aturan deteksi | Tiap aturan bisa diubah sendiri, minimal 1 detik |

Skenario lengkap ada di [apps/mobile/PENGUJIAN.md](apps/mobile/PENGUJIAN.md).

### Mematikan

Tutup 3 jendela backend, lalu:

```powershell
docker compose -f infra\docker-compose.yml --env-file .env down
```

### Kalau bermasalah

| Gejala | Penyebab yang mungkin |
|---|---|
| Aplikasi "Gagal memuat data" | HP beda Wi-Fi, port 8000 belum dibuka, atau jaringan laptop Public |
| Kamar 1 tetap Offline | `secrets.h` kosong, port 8883 belum dibuka, atau Wi-Fi ESP32 bukan 2,4 GHz |
| Error TLS di log broker | `MQTT_CA_CERT` berbeda dengan `ca.crt`, atau IP laptop belum ada di sertifikat |
| Kamar 2 tidak pernah bocor | Jendela Simulator tertutup, atau backend belum menyala |
| Build gagal kehabisan memori atau `Cannot copy file` | RAM atau disk hampir penuh |

Detail tiap bagian ada di README masing-masing folder.
