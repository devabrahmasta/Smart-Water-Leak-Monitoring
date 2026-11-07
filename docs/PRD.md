# Product Requirements Document
## Smart Water: Pemantauan dan kendali air per kamar kos, dengan penutupan valve otomatis saat bocor

**Versi:** 1.0.0 (Draft)
**Tanggal:** 7 November 2026
**Basis:** Mode B (sintesis). Sumber: laporan "Smart Water Usage Monitoring & Control System" Tim Timun Mania (IoT IF-C), diskusi rancangan rangkaian dan firmware, `DESIGN.md` v1, dan file Figma *Smart Water UI* (https://www.figma.com/design/BRThPzyDj0I2w2hIrjcnDX). Belum ada kode aplikasi dan *backend*.
**Platform:** Mobile Android (Flutter) + Backend (Python FastAPI, Mosquitto, PostgreSQL) dalam satu monorepo. Firmware ESP32 ikut di monorepo sebagai konsumen kontrak MQTT.
**Pengguna dokumen:** Tim Timun Mania, dosen dan asisten Praktikum IoT, *coding agent* yang dipakai untuk *vibecoding*.
**Cakupan:** *Frontend* (aplikasi mobile) dan *backend*. Firmware hanya diatur sejauh kontrak MQTT-nya.

> Setiap persyaratan diberi **status** dan setiap angka target diberi **dasar**. Karena belum ada kode, semua status ⬜ Planned. Lihat Bagian 0.

---

## 0. Cara Membaca Dokumen Ini

### 0.1 Legenda Status

| Status | Arti |
|---|---|
| ✅ Implemented | Ada di kode dan berfungsi sesuai deskripsi (diverifikasi dengan membaca kode; belum tentu diuji di perangkat) |
| 🟡 Partial | Ada sebagian; celahnya dijelaskan di bawahnya |
| ⬜ Planned | Belum ada di kode; masuk roadmap |
| 🐞 Defect | Ada di kode tetapi perilakunya salah; lihat Bagian 5.3 |

### 0.2 Legenda Dasar Angka

| Dasar | Arti |
|---|---|
| **Laporan** | Nilai dari laporan Tim Timun Mania (slide Aturan Deteksi, Cara Kerja Sistem, Flowchart). Setara "PRD v0": tertulis, belum diverifikasi di kode |
| **Standar** | Rujukan resmi eksternal (Lampiran A) |
| **Usulan** | Ditetapkan penulis PRD; belum terukur, perlu disetujui tim |
| **Terukur** | Ada hasil pengujian (sebutkan file/laporan) |
| **TBD** | Belum ada dasar; masuk Pertanyaan Terbuka |

---

## 1. Executive Summary

### 1.1 Problem Statement
Pemilik kos membayar tagihan air dari satu meteran induk, padahal pemakaian tersebar ke banyak kamar. Kebocoran pipa atau keran yang lupa ditutup baru ketahuan saat tagihan sudah membengkak, karena tidak ada data per kamar dan tidak ada cara menutup aliran dari jauh.

### 1.2 Proposed Solution
Satu perangkat ESP32 per kamar mengukur debit dengan sensor YF-S201, menjalankan 3 aturan kebocoran secara mandiri, dan langsung menutup *solenoid valve* sebelum mengirim alert. *Backend* menyimpan data, menghitung rekap harian dan bulanan, mendeteksi anomali pemakaian, dan mengirim *push notification*. Aplikasi mobile menampilkan pemakaian per kamar dan memberi kendali buka/tutup valve dengan konfirmasi ACK dari perangkat.

### 1.3 Success Criteria (KPI)

| ID | KPI | Target | Dasar | Cara verifikasi |
|---|---|---|---|---|
| K1 | Waktu dari ESP32 *publish* alert LEAK sampai *push notification* terkirim ke FCM | ≤ 15 dtk (p95) | **Usulan** (alert dikirim seketika, bukan menunggu siklus telemetri 10 dtk; 15 dtk = 1,5 × siklus telemetri sebagai batas aman) | Log *backend*: selisih `alerts.device_ts` dan `notifications.sent_at`; uji 20 kali dengan simulator |
| K2 | Waktu perintah valve dari aplikasi sampai status SUCCESS diterima | ≤ 15 dtk (p95); lebih dari itu dianggap FAILED | **Usulan** (ESP32 mengecek perintah tiap siklus 1 dtk; sisanya cadangan jaringan) | Log `valve_commands.created_at` vs `acked_at`; uji 20 kali di perangkat nyata |
| K3 | Kesegaran data di aplikasi (umur data terbaru saat tampil) | ≤ 20 dtk pada kondisi online | **Usulan** (telemetri 10 dtk **Laporan** + *polling* aplikasi 10 dtk) | Bandingkan label "Data x detik lalu" dengan jam server, 10 sampel |
| K4 | Telemetri yang hilang saat ESP32 *offline* lalu tersambung lagi | 0 baris hilang, 0 baris ganda untuk *offline* 5 menit | **Usulan** | Uji putus WiFi 5 menit, hitung baris per `msg_id` di tabel `telemetry` |
| K5 | Selisih rekap harian vs jumlah volume mentah | ≤ 1% | **Usulan** | *Unit test* job agregasi + query pembanding di data demo |
| K6 | Kepatuhan UI terhadap komponen Figma | 100% layar MVP hanya memakai komponen dari `DESIGN.md` bagian 6 | **Usulan** | *Review* manual tiap layar terhadap Figma page *Screens* |

> **Catatan pembanding:** Smart Water BUKAN meter air resmi dan tidak dipakai untuk penagihan. YF-S201 adalah sensor hobi dengan akurasi rendah, jadi angka liter dibandingkan antar kamar dan antar hari, bukan dengan meteran PDAM.

---

## 2. User Experience & Functionality

### 2.1 Persona

| Persona | Deskripsi | Kebutuhan utama |
|---|---|---|
| **P1 Pemilik kos** (contoh UI: Pak Hendra, Kos Melati) | Satu akun, punya banyak kamar, tidak tinggal di lokasi | Tahu kamar mana yang boros atau bocor, menutup dan membuka valve dari jauh, dapat kabar seketika |
| **P2 Penghuni** | Tidak memakai aplikasi | Bisa membuka valve lewat tombol fisik saat WiFi mati atau salah deteksi |
| **P3 Tim pengembang** | 4 mahasiswa, demo dengan 2 kamar (1 nyata, 1 simulator) | Kontrak data jelas supaya mobile, *backend*, firmware, dan simulator bisa dikerjakan paralel |

### 2.2 User Stories & Acceptance Criteria

#### A. Beranda

**US-01 Ringkasan pemakaian**: ⬜ Planned
*Sebagai pemilik kos, saya ingin melihat total pemakaian hari ini dan bulan ini di layar pertama agar saya tahu kondisi kos tanpa membuka tiap kamar.*
- Summary Card menampilkan total liter hari ini (zona waktu Asia/Jakarta), total bulan berjalan, dan 7 bar mini harian dengan bar terakhir = hari ini.
- Angka memakai format Indonesia: `4.812 L`, `6,4 L/menit`.
- Link "Lihat grafik" membuka Detail Grafik (US-04).
- Data diperbarui otomatis tiap 10 dtk (**Usulan**) selama layar aktif, berhenti saat aplikasi di latar belakang.

**US-02 Daftar "Perlu dicek"**: ⬜ Planned
*Sebagai pemilik kos, saya ingin Beranda hanya menampilkan kamar yang bermasalah agar layar tetap pendek meski kamar saya banyak.*
- Hanya Room Card berstatus Bocor, Valve tertutup, atau Offline yang tampil, urut: Bocor, Offline, Tertutup.
- Bila tidak ada, tampil komponen Empty State "Semua kamar normal".
- Status Tally menampilkan jumlah kamar Normal, Valve tertutup, Offline.

**US-03 Alert Banner**: ⬜ Planned
*Sebagai pemilik kos, saya ingin peringatan aktif paling atas agar tidak terlewat.*
- Banner muncul hanya bila ada alert berstatus OPEN. Bila lebih dari satu, tampilkan yang terbaru dan teks "+n lainnya".
- Varian Kebocoran (merah) untuk tipe LEAK, varian Anomali (netral) untuk ANOMALY.
- Tombol Lihat membuka sheet detail alert (US-11).

#### B. Grafik

**US-04 Detail Grafik**: ⬜ Planned
*Sebagai pemilik kos, saya ingin melihat tren pemakaian harian dan bulanan agar bisa membandingkan dengan tagihan.*
- Segmented Harian (tanggal 1 sampai hari ini di bulan berjalan) dan Bulanan (6 bulan terakhir).
- Bar tertinggi biru dengan label nilai; tap bar lain menampilkan nilainya.
- 2 Metric Tile: total periode dan rata-rata (harian atau bulanan).
- Room Compare menampilkan semua kamar urut pemakaian terbesar pada periode terpilih.
- Bila belum ada data: grafik diganti teks "Belum ada data pemakaian", bukan sumbu kosong.

#### C. Kamar

**US-05 Daftar kamar**: ⬜ Planned
*Sebagai pemilik kos, saya ingin melihat semua kamar dalam satu daftar agar bisa menuju kamar mana pun dalam satu tap.*
- Satu Room Card per kamar dengan nama, liter hari ini, debit sekarang, chip status, dan saklar valve.
- Filter Segmented: Semua, Perlu dicek, Offline.
- Kamar dengan pemakaian terbesar hari ini diberi chip Tertinggi.
- Daftar mendukung minimal 50 kamar tanpa patah (**Usulan**); pakai *lazy list*.

**US-06 Detail kamar**: ⬜ Planned
*Sebagai pemilik kos, saya ingin melihat riwayat satu kamar agar tahu penyebab masalahnya.*
- Isi: Room Card, Metric Tile bulan ini dan rata-rata harian, grafik harian kamar ini, 10 Command Row terakhir, 3 Alert Item terakhir.
- Label "Data x detik lalu" dari `last_seen_at` perangkat.

#### D. Kendali valve

**US-07 Menutup valve dari aplikasi**: ⬜ Planned
*Sebagai pemilik kos, saya ingin menutup valve kamar tertentu dari jauh agar air berhenti saat saya curiga ada masalah.*
- Geser saklar ke off memunculkan Confirm Sheet "Tutup valve Kamar n?". Batal tidak mengirim apa pun.
- Setelah konfirmasi, saklar masuk state Pending dan tidak bisa disentuh ulang.
- Status valve di layar baru berubah setelah ACK SUCCESS (K2). Bila 15 dtk tanpa ACK, perintah FAILED, saklar kembali ke posisi semula, Toast error "Perangkat tidak merespons. Coba lagi".
- Hasil tercatat di riwayat dengan sumber Aplikasi.

**US-08 Membuka valve setelah kebocoran**: ⬜ Planned
*Sebagai pemilik kos, saya ingin membuka valve setelah penyebab bocor diperbaiki agar penghuni bisa memakai air lagi.*
- Valve yang ditutup otomatis tidak pernah dibuka otomatis oleh sistem (**Laporan**).
- Confirm Sheet berisi peringatan "Buka hanya kalau penyebabnya sudah dicek".
- ACK SUCCESS untuk OPEN mengubah semua alert LEAK berstatus OPEN di kamar itu menjadi RESOLVED dengan `resolved_by = APP`.
- Toast sukses "Valve Kamar n terbuka".

**US-09 Perangkat offline**: ⬜ Planned
*Sebagai pemilik kos, saya ingin tahu bila perangkat kamar tidak terhubung agar tidak mengira datanya nol.*
- Perangkat dianggap Offline bila tidak ada pesan selama 30 dtk (**Usulan**: 3 × siklus telemetri 10 dtk).
- Room Card Offline: angka diganti "Tidak ada data", saklar disabled dengan teks "Kontrol tidak tersedia", tampil "Terakhir terlihat hh.mm".
- API menolak perintah valve ke perangkat offline dengan 409 `DEVICE_OFFLINE`.

**US-10 Aktivitas tombol fisik**: ⬜ Planned
*Sebagai pemilik kos, saya ingin dikabari bila valve diubah lewat tombol fisik agar status di aplikasi tidak berubah tanpa saya tahu.*
- Pesan status dengan `source = MANUAL_BUTTON` dicatat di `valve_commands` dengan `user_id` kosong dan `result = SUCCESS`.
- Muncul di riwayat dengan ikon tangan: "Buka valve · Tombol fisik · 14.20".
- Membuat alert tipe ACTIVITY (status INFO, tanpa chip Aktif) dan *push notification* "Valve Kamar n dibuka lewat tombol fisik".
- Bila valve dibuka lewat tombol saat ada alert LEAK OPEN, alert itu menjadi RESOLVED dengan `resolved_by = MANUAL_BUTTON`.

#### E. Notifikasi

**US-11 Daftar dan detail notifikasi**: ⬜ Planned
*Sebagai pemilik kos, saya ingin melihat semua kejadian di satu tempat agar bisa menelusuri apa yang terjadi.*
- Filter Semua, Aktif (OPEN), Selesai (RESOLVED). ACTIVITY hanya tampil di Semua.
- Tiap item: tipe, kamar, aturan yang terpicu atau sumber, waktu.
- Tap membuka sheet detail. Untuk LEAK yang valve-nya tertutup, sheet berisi tombol Buka valve (alur US-08).
- Badge di tab Notifikasi = jumlah alert OPEN, hilang saat 0 dan saat tab aktif.

**US-12 Push kebocoran**: ⬜ Planned
*Sebagai pemilik kos, saya ingin dapat push notification saat bocor agar bisa bertindak meski aplikasi tertutup.*
- Teks: "Kebocoran di Kamar n, valve ditutup". Tap membuka Detail Kamar terkait.
- Memenuhi K1. Bila FCM gagal, *backend* mencoba ulang 3 kali dengan jeda 5, 15, 45 dtk (**Usulan**) lalu mencatat gagal (**Laporan**: "catat gagal dan coba kirim ulang").

**US-13 Push anomali**: ⬜ Planned
*Sebagai pemilik kos, saya ingin dikabari bila pemakaian satu kamar jauh di atas biasanya agar bisa menegur penghuni sebelum tagihan datang.*
- Teks: "Pemakaian Kamar n hari ini 1,7× rata-rata".
- Maksimal 1 alert anomali per kamar per hari (**Usulan**) supaya tidak spam.

#### F. Backend dan data

**US-14 Menerima telemetri**: ⬜ Planned
*Sebagai sistem, saya harus menyimpan setiap telemetri valid agar grafik dan deteksi berjalan.*
- Ingest *subscribe* topik telemetri, validasi skema JSON (Bagian 4.4), simpan, dan perbarui `devices.last_seen_at`.
- Pesan tidak valid dibuang dan dicatat di log dengan alasan (**Laporan**).
- Pesan dengan `msg_id` yang sudah ada diabaikan (*idempotent*), memenuhi K4 saat ESP32 mengirim ulang isi buffer.

**US-15 Rekap harian dan bulanan**: ⬜ Planned
*Sebagai sistem, saya harus merangkum volume per kamar agar grafik tidak menghitung ulang data mentah.*
- APScheduler menjalankan job tiap 5 menit (**Usulan**) untuk hari berjalan dan pukul 00.10 WIB untuk menutup hari sebelumnya.
- Memenuhi K5.

**US-16 Deteksi anomali di server**: ⬜ Planned
*Sebagai sistem, saya harus membandingkan pemakaian harian dengan rata-rata historis agar pemakaian boros terdeteksi.*
- Anomali bila pemakaian kamar hari ini > 1,5 × rata-rata harian kamar itu (**Laporan**) pada jendela 7 hari sebelumnya (**Usulan**, lihat Pertanyaan Terbuka).
- Butuh minimal 3 hari data historis sebelum aturan aktif (**Usulan**).
- Dicek tiap jam (**Usulan**).

**US-17 Simulator kamar dummy**: ⬜ Planned
*Sebagai tim, kami butuh kamar kedua yang perilakunya sama dengan perangkat nyata agar kontrol per kamar bisa didemokan.*
- Skrip Python memakai topik dan format MQTT yang sama (**Laporan**).
- Menerima perintah CLOSE/OPEN dan membalas ACK, bisa dipaksa skenario: normal, bocor kontinu, bocor stabil, jam sepi, offline, gagal ACK.
- Aplikasi tidak membedakan kamar nyata dan simulator.

#### G. Kondisi tepi aplikasi

**US-18 Penggunaan pertama tanpa data**: ⬜ Planned
*Sebagai pemilik kos, saya ingin aplikasi tetap jelas saat belum ada data agar tidak terlihat rusak.*
- Tanpa kamar terdaftar: Beranda dan Kamar menampilkan "Belum ada kamar terhubung".
- Kamar tanpa telemetri: status Offline dengan "Belum pernah terhubung".

**US-19 Koneksi aplikasi ke server gagal**: ⬜ Planned
*Sebagai pemilik kos, saya ingin tahu bila aplikasi gagal mengambil data agar tidak membaca angka basi.*
- Tampilkan data terakhir yang tersimpan dan baris "Gagal memperbarui · Coba lagi" di atas konten.
- Saklar valve disabled selama server tidak terjangkau.

**US-20 Izin notifikasi ditolak**: ⬜ Planned
*Sebagai pemilik kos, saya ingin aplikasi tetap bekerja bila saya menolak izin notifikasi.*
- Aplikasi meminta izin saat pertama dibuka (Android 13+).
- Bila ditolak, tab Notifikasi tetap berisi daftar, dan Beranda menampilkan satu baris "Notifikasi mati. Aktifkan di Pengaturan" yang bisa ditutup.

### 2.3 Non-Goals
- Login, registrasi, banyak akun, dan peran admin. MVP memakai satu pemilik (Bagian 4.5 menjelaskan autentikasinya).
- Banyak properti kos dalam satu akun.
- Pembayaran atau penagihan otomatis (**Laporan**).
- Notifikasi lewat Telegram, WhatsApp, atau email (**Laporan**: hanya lewat aplikasi).
- Machine learning untuk deteksi (**Laporan**: berbasis aturan ambang).
- Lokasi titik bocor di dalam kamar (**Laporan**).
- Mengubah ambang deteksi dari aplikasi. Nilai default disimpan di tabel `rule_params` dan diubah lewat database atau *seed*.
- Tutup semua kamar sekaligus.
- iOS dan mode gelap. Flutter memungkinkan keduanya nanti, tapi tidak diuji di MVP.

---

## 3. AI System Requirements

Tidak berlaku. Deteksi kebocoran dan anomali murni aturan ambang deterministik (Bagian 4.6). Tidak ada model ML atau LLM di produk.

---

## 4. Technical Specifications

### 4.1 Arsitektur

```
[ESP32 + YF-S201 + relay + valve]          [Simulator Python]
        │  MQTT over TLS :8883                    │  (topik & format sama)
        └───────────────┬─────────────────────────┘
                        ▼
                [Mosquitto broker]
                        │
          ┌─────────────┼──────────────┐
          ▼             ▼              ▲ cmd
   [Ingest worker] [Command worker]────┘
          │             │
          ▼             ▼
            [PostgreSQL]  ◄── [APScheduler: agregasi, anomali, offline, timeout]
                 ▲
                 │
         [FastAPI REST /v1] ──► [Notification service] ──► FCM ──► HP pemilik
                 ▲
                 │ HTTPS + token
          [Aplikasi Flutter]
```

| Lapisan | Teknologi | Peran | Dasar |
|---|---|---|---|
| Perangkat | ESP32, C++ Arduino, PubSubClient, WiFiClientSecure, ArduinoJson, NTP | Ukur debit, 3 aturan bocor, tutup valve, kirim telemetri/alert/status, terima perintah | **Laporan** |
| Broker | Mosquitto, TLS port 8883, kredensial per perangkat | Perantara pesan | **Laporan** |
| Backend | Python 3.12, FastAPI, SQLAlchemy 2, Alembic, Pydantic v2, paho-mqtt | REST API, ingest, perintah valve, notifikasi | **Laporan** (FastAPI); versi dan library pendukung **Usulan** |
| Scheduler | APScheduler | Agregasi, anomali, deteksi offline, timeout perintah | **Laporan** |
| Database | PostgreSQL 16 (TimescaleDB opsional, tidak dipakai di MVP) | Satu basis data untuk semua data | **Laporan** |
| Mobile | Flutter 3.x, Riverpod, go_router, dio, fl_chart, firebase_messaging | UI sesuai Figma, *polling* data, kendali valve | Flutter **Laporan**; library **Usulan** |
| Push | Firebase Cloud Messaging | Alert ke HP pemilik | **Laporan** |
| Simulator | Python, paho-mqtt | Kamar dummy | **Laporan** |

Keputusan implementasi:
1. **Kontrak dulu.** Skema REST dan MQTT ditulis di `packages/contracts` sebelum kode apa pun. Mobile, *backend*, firmware, dan simulator hanya boleh mengikuti kontrak itu.
2. **Satu proses backend untuk MVP.** FastAPI, worker MQTT, dan APScheduler berjalan dalam satu proses (lifespan FastAPI) supaya *deploy* mudah. Dipisah nanti bila perlu.
3. **Aplikasi memakai *polling*, bukan WebSocket.** Interval 10 dtk di layar aktif, 1 dtk saat menunggu ACK perintah. Lebih sederhana dan cukup untuk K3.
4. **Waktu disimpan UTC, ditampilkan WIB.** Batas hari untuk rekap memakai Asia/Jakarta.
5. **Relay diasumsikan terpasang di terminal NC** (hasil diskusi rangkaian), jadi "tutup valve" = relay ON. Firmware wajib menyimpan status tertutup di memori non-volatil, lihat risiko di 5.5.

### 4.2 Struktur Monorepo

```
smart-water/
├── AGENTS.md                 # aturan untuk coding agent (wajib dibaca tiap sesi)
├── README.md                 # cara menjalankan semuanya
├── docs/
│   ├── PRD.md                # dokumen ini
│   ├── DESIGN.md             # token dan komponen UI
│   └── decisions/            # catatan keputusan (ADR) singkat
├── packages/
│   └── contracts/
│       ├── openapi.json      # diekspor dari FastAPI, di-commit
│       ├── mqtt.md           # topik dan payload
│       ├── schemas/*.json    # JSON Schema payload MQTT
│       └── fixtures/*.json   # contoh respons dan payload untuk tes
├── apps/
│   └── mobile/               # Flutter
│       └── lib/
│           ├── core/         # tema dari DESIGN.md, router, dio client, format angka
│           ├── components/   # widget = komponen Figma (1 file per komponen)
│           ├── features/     # home, usage, rooms, room_detail, alerts
│           └── data/         # model, repository, API
├── services/
│   ├── api/                  # FastAPI + worker MQTT + scheduler
│   │   ├── app/
│   │   │   ├── api/v1/       # router REST
│   │   │   ├── mqtt/         # ingest, command, status
│   │   │   ├── jobs/         # agregasi, anomali, offline, timeout
│   │   │   ├── rules/        # logika anomali (fungsi murni)
│   │   │   ├── notify/       # FCM
│   │   │   ├── models/       # SQLAlchemy
│   │   │   └── schemas/      # Pydantic (sumber openapi.json)
│   │   ├── migrations/       # Alembic
│   │   └── tests/
│   └── simulator/
├── firmware/
│   └── esp32/                # sketch Arduino
├── infra/
│   ├── docker-compose.yml    # postgres + mosquitto
│   └── mosquitto/            # config TLS, ACL per perangkat
├── .env.example
└── Makefile                  # make dev, make test, make contracts
```

Aturan monorepo:
1. Satu repo, satu `main`. Setiap fitur di cabang sendiri dan *merge* setelah tes lulus.
2. Perubahan kontrak selalu dalam *commit* yang sama dengan perubahan kode yang memakainya.
3. Rahasia hanya di `.env` lokal dan tidak pernah di-commit. `.env.example` berisi nama variabel tanpa nilai.

### 4.3 Model Data

| Tabel | Kolom penting | Catatan |
|---|---|---|
| `rooms` | id, name, sort_order, is_simulated | Nama tampil "Kamar 1" |
| `devices` | id (string, sama dengan client ID MQTT), room_id, valve_state (OPEN/CLOSED), last_seen_at, firmware_version | Satu perangkat per kamar |
| `telemetry` | id, device_id, msg_id (unik per perangkat), device_ts, received_at, flow_lpm, volume_l_delta, valve_state | Data mentah tiap 10 dtk |
| `daily_usage` | room_id, date (WIB), volume_l, peak_flow_lpm | Unik (room_id, date) |
| `monthly_usage` | room_id, month, volume_l | Unik (room_id, month) |
| `alerts` | id, room_id, type (LEAK/ANOMALY/ACTIVITY), rule (CONTINUOUS/STABLE/QUIET_HOURS/DAILY_RATIO/MANUAL_BUTTON), status (OPEN/RESOLVED/INFO), device_ts, created_at, resolved_at, resolved_by (APP/MANUAL_BUTTON), detail (JSON) | |
| `valve_commands` | id, room_id, action (OPEN/CLOSE), source (APP/AUTO/MANUAL_BUTTON), user_id (nullable), status (PENDING/SUCCESS/FAILED), created_at, acked_at | Semua perubahan valve dari sumber mana pun (**Laporan**) |
| `rule_params` | key, value | leak_duration_min, stable_duration_min, stable_variation_pct, night_flow_threshold_lpm, night_duration_min, quiet_start, quiet_end, anomaly_ratio, anomaly_window_days (**Laporan** untuk 7 nama pertama) |
| `push_tokens` | token, platform, updated_at | Token FCM HP pemilik |
| `notifications` | id, alert_id, sent_at, attempts, last_error | Bukti K1 |

### 4.4 Kontrak MQTT

Semua topik di bawah `swm/{device_id}/`. QoS 1. Payload JSON UTF-8.

| Topik | Arah | Kapan | Isi utama |
|---|---|---|---|
| `telemetry` | ESP32 → broker | Tiap 10 dtk (**Laporan**) | `msg_id`, `ts`, `flow_lpm`, `volume_l_delta`, `valve` |
| `alert` | ESP32 → broker | Seketika setelah valve ditutup karena aturan | `msg_id`, `ts`, `rule`, `flow_lpm`, `valve: "CLOSED"` |
| `status` | ESP32 → broker | Setiap valve berubah karena tombol fisik, dan sekali saat boot | `msg_id`, `ts`, `valve`, `source` |
| `cmd` | broker → ESP32 | Saat pemilik menekan buka/tutup | `command_id`, `action` |
| `ack` | ESP32 → broker | Setelah perintah dieksekusi | `command_id`, `result`, `valve` |

Contoh telemetri:
```json
{ "msg_id": 18342, "ts": "2026-11-07T07:21:30Z", "flow_lpm": 6.4, "volume_l_delta": 1.07, "valve": "OPEN" }
```

Aturan kontrak:
1. `msg_id` naik monoton per perangkat dan bertahan setelah reboot (disimpan di NVS), dipakai *backend* untuk dedup.
2. Pesan dari buffer *offline* dikirim ulang apa adanya, dengan `ts` asli dari perangkat.
3. `ts` dari NTP. Bila NTP belum sinkron, perangkat mengirim `ts: null` dan *backend* memakai `received_at`.

### 4.5 Kontrak REST (ringkas)

Base URL `/v1`. Semua respons JSON, waktu ISO 8601 UTC. Header `Authorization: Bearer <OWNER_TOKEN>`.

| Method | Path | Fungsi | Dipakai layar |
|---|---|---|---|
| GET | `/summary` | Total hari ini, bulan ini, 7 hari, tally status, alert OPEN terbaru | Beranda |
| GET | `/rooms?filter=all\|attention\|offline` | Daftar kamar dengan status dan angka hari ini | Beranda, Kamar |
| GET | `/rooms/{id}` | Detail kamar | Detail Kamar |
| GET | `/rooms/{id}/usage?period=daily\|monthly` | Seri grafik per kamar | Detail Kamar |
| GET | `/usage?period=daily\|monthly` | Seri grafik semua kamar + perbandingan per kamar | Detail Grafik |
| GET | `/rooms/{id}/commands?limit=10` | Riwayat perintah | Detail Kamar |
| POST | `/rooms/{id}/valve` body `{ "action": "OPEN" \| "CLOSE" }` | Buat perintah, balas 202 + `command_id` | Room Card, Confirm Sheet |
| GET | `/commands/{id}` | Status perintah (PENDING/SUCCESS/FAILED) | *Polling* setelah POST |
| GET | `/alerts?status=all\|open\|resolved` | Daftar notifikasi | Notifikasi |
| GET | `/alerts/{id}` | Detail alert | Sheet detail |
| POST | `/push-tokens` | Daftarkan token FCM | Saat aplikasi dibuka |
| GET | `/health` | Cek DB dan broker | Monitoring |

Kode galat: 401 token salah, 404 tidak ada, 409 `DEVICE_OFFLINE` atau `COMMAND_IN_PROGRESS`, 422 validasi.

Autentikasi MVP: tidak ada layar login. *Backend* tetap mewajibkan satu token pemilik statis yang dibaca dari env. Aplikasi menerima token lewat `--dart-define` saat *build* sehingga tidak tertulis di kode atau repo. Ini kompromi demo, lihat 4.7 dan 5.5.

### 4.6 Aturan Deteksi

| Aturan | Tempat | Kondisi | Nilai default | Dasar |
|---|---|---|---|---|
| Aliran kontinu | ESP32 | flow > 0 tanpa jeda > `leak_duration_min` | 45 menit | **Laporan** |
| Aliran stabil | ESP32 | variasi flow ≤ `stable_variation_pct` selama ≥ `stable_duration_min` | ±10%, 5 menit | **Laporan** |
| Aliran jam sepi | ESP32 | flow > `night_flow_threshold_lpm` selama `night_duration_min` pada `quiet_start` sampai `quiet_end` | 1,0 L/menit, 5 menit, 01.00 sampai 04.00 | **Laporan** (jam bertentangan, lihat Pertanyaan Terbuka) |
| Anomali harian | Server | pemakaian hari ini > `anomaly_ratio` × rata-rata `anomaly_window_days` hari | 1,5 × | Rasio **Laporan**, jendela 7 hari **Usulan** |
| Konversi debit | ESP32 | L/menit = pulsa per detik ÷ 7,5 | 7,5 | **Standar** (datasheet YF-S201, Lampiran A) |

### 4.7 Titik Integrasi

| Integrasi | Dipakai oleh | Catatan |
|---|---|---|
| Mosquitto (TLS 8883) | ESP32, simulator, *backend* | Username/password per perangkat, ACL: perangkat hanya boleh *publish/subscribe* topik `swm/{dirinya}/#`. Bila broker mati, *backend* mencoba sambung ulang tiap 5 dtk (**Usulan**) |
| FCM HTTP v1 | Notification service | Kunci *service account* hanya di server. Gagal: coba ulang (US-12) |
| NTP | ESP32 | Wajib untuk aturan jam sepi. Bila gagal, aturan jam sepi nonaktif sampai waktu sinkron |
| Figma *Smart Water UI* | Pengembangan mobile | Sumber visual. Ambil konteks per komponen lewat Figma MCP saat membangun widget |

### 4.8 Keamanan & Privasi

Data yang disimpan hanya pemakaian air per kamar dan token FCM. Tidak ada nama penghuni. Pihak ketiga yang menerima data: Firebase (isi notifikasi).

| Persyaratan | Status | Catatan |
|---|---|---|
| Autentikasi *endpoint* REST | ⬜ Planned | Bearer token pemilik. Semua route kecuali `/health` menolak 401 tanpa token |
| Kredensial tidak ikut terbundel di aplikasi | ⬜ Planned | Token lewat `--dart-define`, tidak di repo. Tetap bisa diekstrak dari APK, jadi hanya layak untuk demo (Pertanyaan Terbuka 4) |
| Kredensial tidak ada di firmware repo | ⬜ Planned | SSID, password WiFi, dan kredensial MQTT di `secrets.h` yang masuk `.gitignore` |
| Validasi sertifikat TLS di ESP32 | ⬜ Planned | Wajib `setCACert` dengan CA broker. `setInsecure()` dilarang |
| TLS di REST API | ⬜ Planned | HTTPS saat *deploy*. Lokal boleh HTTP |
| ACL broker per perangkat | ⬜ Planned | Perangkat tidak bisa mengirim perintah ke perangkat lain |
| Persetujuan izin notifikasi | ⬜ Planned | US-20 |
| Atribusi | ⬜ Planned | Ikon Lucide (lisensi ISC) dicantumkan di layar Tentang atau README |

---

## 5. Risks, Defects & Roadmap

### 5.1 Fase Rilis

| Fase | Isi | Status |
|---|---|---|
| **MVP (demo 15 Nov 2026)** | US-01 sampai US-20, 2 kamar (1 nyata, 1 simulator) | ⬜ Planned |
| **v1.1** | Login pemilik dengan token per sesi, ubah ambang dari aplikasi, mode gelap | ⬜ Planned |
| **v2.0** | Banyak properti, peran penghuni, iOS | ⬜ Planned |

Tanggal demo dari timeline laporan (26 Okt sampai 15 Nov 2026).

### 5.2 Langkah Pengerjaan (urutan untuk *vibecoding*)

Satu langkah = satu sesi *agent* = satu cabang. Jangan lanjut sebelum kriteria selesai terpenuhi.

| ID | Langkah | Kriteria selesai |
|---|---|---|
| **R-00** | Kerangka monorepo: folder 4.2, `AGENTS.md`, `Makefile`, `.env.example`, `docker-compose.yml` (Postgres + Mosquitto TLS) | `make dev` menyalakan Postgres dan Mosquitto; `mosquitto_pub` dengan TLS berhasil |
| **R-01** | Kontrak: `mqtt.md`, JSON Schema 5 payload, fixtures contoh | Setiap fixture lolos validasi skemanya lewat satu tes |
| **R-02** | Backend: model, migrasi Alembic, *seed* 2 kamar + `rule_params` default | `alembic upgrade head` dari DB kosong sukses; *seed* menghasilkan 2 kamar |
| **R-03** | Ingest MQTT: telemetri, alert, status, dedup `msg_id`, `last_seen_at` | Tes integrasi: kirim fixture, baris tersimpan; kirim ulang, tidak ganda (K4) |
| **R-04** | Simulator dengan 6 skenario US-17 | Simulator skenario normal menghasilkan telemetri tiap 10 dtk yang lolos ingest |
| **R-05** | Perintah valve: POST, publish `cmd`, terima `ack`, timeout 15 dtk jadi FAILED, resolve alert | Tes: ACK sukses → SUCCESS; tanpa ACK → FAILED dalam 15 dtk; OPEN me-RESOLVE alert LEAK |
| **R-06** | Job: agregasi, anomali, deteksi offline 30 dtk | *Unit test* fungsi murni `rules/` untuk batas 1,49× dan 1,51×; K5 lulus di data simulator 3 hari |
| **R-07** | REST API lengkap 4.5 + ekspor `openapi.json` ke `packages/contracts` | Tiap *endpoint* punya tes respons terhadap fixture; `make contracts` tidak menghasilkan diff |
| **R-08** | Notifikasi FCM + retry + aktivitas tombol fisik | Alert dari simulator sampai di HP uji; log memenuhi K1 di 20 percobaan |
| **R-09** | Mobile fondasi: tema dari `DESIGN.md` (warna, teks, radius, bayangan), router 3 tab, dio client, format angka id_ID | Layar kosong 3 tab tampil dengan tema benar; tes format `4812 → "4.812 L"` |
| **R-10** | Mobile komponen: 18 widget sesuai Figma page *Components* | Halaman galeri internal menampilkan semua varian; dibandingkan screenshot Figma |
| **R-11** | Mobile layar: Beranda, Detail Grafik, Kamar, Detail Kamar, Notifikasi + data dari API | Semua layar memakai data asli dari *backend* lokal + simulator |
| **R-12** | Mobile kendali valve + *polling* ACK + push + kondisi tepi US-18 sampai US-20 | Skenario di Figma baris *Skenario* bisa direproduksi semua di HP |
| **R-13** | Integrasi perangkat nyata (firmware mengikuti kontrak) dan uji end-to-end | Uji Skenario A (normal) dan B (bocor, tutup valve, buka dari aplikasi) dari laporan lulus |

### 5.3 Cacat Diketahui

Belum ada; dokumen belum diverifikasi terhadap kode.

### 5.4 Strategi Pengujian
- **Backend, seam tertinggi:** tes integrasi yang menjalankan Postgres dan Mosquitto asli lewat docker-compose, mengirim fixture MQTT, lalu memeriksa respons REST. Ini menguji ingest, DB, dan API sekaligus.
- **Logika aturan:** fungsi murni di `services/api/app/rules/` diuji dengan *unit test* berbasis tabel (nilai tepat di batas ambang).
- **Kontrak:** satu tes memvalidasi semua fixture terhadap JSON Schema, dan satu tes memastikan `openapi.json` sama dengan hasil ekspor terbaru.
- **Mobile:** *widget test* per komponen dengan *golden image* untuk varian utama; tes repository memakai fixture dari `packages/contracts/fixtures` sebagai respons palsu. Tidak menguji detail state internal.
- **End-to-end:** manual dengan simulator, mengikuti daftar skenario di Figma page *Screens* baris *Skenario*.

### 5.5 Risiko Teknis

| Risiko | Kemungkinan | Dampak | Mitigasi |
|---|---|---|---|
| Relay di NC: ESP32 reboot saat bocor membuat relay lepas dan valve terbuka sendiri, melanggar aturan "tidak dibuka otomatis" | Sedang | Air bocor mengalir lagi tanpa pemilik tahu | Firmware simpan `valve_closed` di NVS dan nyalakan relay saat boot; kirim `status` saat boot sehingga *backend* tahu. Alternatif: pindah ke NO (Pertanyaan Terbuka 3) |
| Token pemilik bisa diekstrak dari APK | Tinggi | Orang lain bisa mengendalikan valve | Hanya untuk demo; v1.1 ganti login (5.1) |
| Tekanan air di demo terlalu rendah untuk valve 0,02 sampai 0,8 MPa | Sedang | Valve tidak membuka penuh, sensor tidak terbaca | Beli varian tekanan rendah atau pakai pompa |
| YF-S201 tidak akurat di debit rendah | Tinggi | Aturan jam sepi 1 L/menit dekat batas bawah sensor | Kalibrasi faktor 7,5 dengan wadah ukur sebelum demo |
| Waktu NTP gagal | Rendah | Aturan jam sepi salah jam | Nonaktifkan aturan jam sepi sampai sinkron (4.7) |
| *Agent* mengubah kontrak tanpa sadar | Sedang | Mobile dan *backend* tidak cocok | Tes kontrak di 5.4 + aturan `AGENTS.md` |

### 5.6 Panduan Eksekusi Vibecoding

Praktik yang dipakai di setiap langkah 5.2:

1. **Konteks tetap.** Tiap sesi *agent* dimulai dengan membaca `AGENTS.md`, `docs/PRD.md` bagian yang relevan, dan `packages/contracts`. Untuk mobile, tambah `docs/DESIGN.md` dan konteks Figma komponen terkait.
2. **Satu langkah per sesi.** Prompt menyebut ID langkah dan kriteria selesainya, misalnya: "Kerjakan R-05 sesuai PRD 5.2. Tulis tesnya dulu dari kriteria selesai, lalu implementasi sampai tes lulus. Jangan ubah file di luar `services/api`."
3. **Tes dulu untuk logika.** Untuk `rules/`, ingest, dan perintah valve, minta *agent* menulis tes dari kriteria selesai sebelum kode. *Agent* tidak boleh mengubah tes supaya lulus.
4. **Rencana sebelum kode.** Untuk langkah besar (R-07, R-11), minta rencana file dan fungsi dulu, setujui, baru jalankan.
5. **Commit kecil.** *Commit* setiap tes hijau. Bila *agent* tersesat, kembali ke *commit* terakhir dan ulangi dengan prompt yang lebih sempit, jangan menambal di atas kode rusak.
6. **Kontrak tidak boleh diam-diam berubah.** Bila *agent* merasa kontrak perlu diubah, ia harus berhenti dan bertanya.
7. **Review manusia.** Satu anggota membaca *diff* sebelum *merge*. Fokus: rahasia ter-commit, `setInsecure`, dan perubahan kontrak.

Isi minimum `AGENTS.md`:
- Struktur folder 4.2 dan perintah `make dev`, `make test`, `make contracts`.
- Sumber kebenaran: kontrak > PRD > DESIGN.md > kode yang ada.
- Larangan: rahasia di repo, `setInsecure()`, warna atau radius di luar token `DESIGN.md`, *border* di UI, membuat komponen UI baru tanpa ada di Figma.
- Bahasa UI: Indonesia, format angka id_ID, zona waktu Asia/Jakarta.

---

## 6. Pertanyaan Terbuka (perlu keputusan tim)

1. **Jam sepi bertentangan di laporan:** tabel Aturan Deteksi menulis 01.00 sampai 04.00, slide Flowchart ESP menulis 00.00 sampai 04.00. PRD memakai 01.00 sampai 04.00 sementara. Mana yang benar?
2. **Jendela rata-rata anomali:** laporan hanya menulis "> 1,5 × rata-rata". PRD mengusulkan 7 hari terakhir dengan minimal 3 hari data. Setuju?
3. **Relay NC atau NO:** NC dipilih saat diskusi rangkaian, tapi berisiko di reboot (5.5). Tetap NC dengan penyimpanan NVS, atau pindah ke NO?
4. **Autentikasi:** setuju token statis lewat `--dart-define` untuk demo, dengan catatan tidak aman untuk produksi?
5. **Hosting backend saat demo:** laptop di jaringan yang sama, VPS, atau layanan cloud? Ini menentukan sertifikat TLS broker.
6. **Konfirmasi angka Usulan:** K1 sampai K6, timeout ACK 15 dtk, offline 30 dtk, *polling* 10 dtk, job agregasi 5 menit, retry FCM 3 kali, maksimal 1 anomali per kamar per hari.
7. **Arah alur di slide Arsitektur 4 Layer:** "Alur Naik" ditulis perintah ke perangkat dan "Alur Turun" telemetri ke server. Biasanya kebalikannya. Perlu dirapikan di laporan?
8. **Kalibrasi sensor:** apakah tim akan mengukur faktor pulsa sendiri sebelum demo, atau tetap 7,5 dari datasheet?

---

## Lampiran A: Rujukan Standar

| Rujukan | Klaim yang dipakai |
|---|---|
| Datasheet YF-S201 (Components101, "YF-S201 Water Flow Measurement Sensor"): https://components101.com/sensors/yf-s201-water-flow-measurement-sensor | Faktor konversi frekuensi pulsa ke debit sekitar 7,5 × Q (L/menit). Datasheet tidak menjamin akurasi di debit sangat rendah |
| OASIS, "MQTT Version 3.1.1": https://docs.oasis-open.org/mqtt/mqtt/v3.1.1/mqtt-v3.1.1.html | Semantik QoS 1 (setidaknya sekali terkirim), dasar keputusan dedup dengan `msg_id` |
| IANA Service Name Registry, port 8883 "secure-mqtt": https://www.iana.org/assignments/service-names-port-numbers | Port standar MQTT over TLS |
| Firebase, "FCM HTTP v1 API": https://firebase.google.com/docs/cloud-messaging/migrate-v1 | Pengiriman push memakai *service account* di server |
| Lucide, "License": https://lucide.dev/license | Lisensi ISC untuk ikon |

## Lampiran B: Nilai Konstan Kode yang Dirujuk

Belum ada kode. Nilai default yang akan menjadi konstanta: telemetri 10 dtk, baca sensor 1 dtk, aturan 45 menit, ±10% 5 menit, 1,0 L/menit 5 menit 01.00 sampai 04.00, anomali 1,5 ×. Setelah kode ada, tabel ini diisi dengan lokasi file dan baris.

---

*Dokumen ini dibuat dari hasil diskusi dan laporan tim pada tanggal di atas, sebelum kode ditulis. Status "Implemented" berarti terlihat di kode, bukan berarti sudah diuji di perangkat fisik. Saat kode mulai ada, perbarui dokumen ini dengan Mode C (audit kode) dan naikkan versinya.*
