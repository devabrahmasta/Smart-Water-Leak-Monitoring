# CONTRACT.md: Smart Water

Versi 1.0 (Draft), 7 November 2026

## 0. Pemilik dan aturan ubah

| Orang | Jalur | Menulis | Membaca |
|---|---|---|---|
| Backend (1) | `services/api`, `infra` | Bagian 2 dan 3, `openapi.json`, `schemas/` | Semua |
| Mobile (1) | `apps/mobile` | Tidak menulis kontrak, hanya mengikuti | Bagian 3 dan 4 |
| Firmware dan hardware (2) | `firmware/esp32`, rangkaian | Tidak menulis kontrak, hanya mengikuti | Bagian 2 |

Aturan ubah:
1. Perubahan kontrak lewat PR. Pemilik jalur yang terdampak wajib setuju sebelum merge.
2. Setiap perubahan menaikkan versi di judul dan menambah satu baris di Bagian 5.
3. Kode tidak boleh menyimpang dari kontrak. Kalau kontraknya yang salah, ubah kontraknya dulu.

## 1. Konvensi umum

1. Waktu: ISO 8601 UTC, misalnya `2026-11-07T07:21:30Z`. Rekap harian dan bulanan dihitung berdasarkan hari WIB, dan itu urusan *backend*.
2. Satuan: debit `flow_lpm` dalam L/menit, volume dalam liter, angka desimal ditulis sebagai angka JSON (bukan teks).
3. Nilai *enum* selalu huruf besar.
4. Status valve: `OPEN` atau `CLOSED`.
5. Format tampilan angka (4.812 L, 6,4 L/menit) adalah urusan aplikasi. Kontrak hanya membawa angka mentah.

## 2. Firmware dan Backend (MQTT)

Broker Mosquitto, TLS port 8883, QoS 1, payload JSON UTF-8. Satu akun per perangkat dengan ACL hanya boleh `swm/{device_id}/#`. Kredensial tidak ditulis di repo. `device_id` kamar 1 adalah `1`, dan kamar 2 (simulator) adalah `2`.

| Topik `swm/{device_id}/...` | Arah | Kapan |
|---|---|---|
| `telemetry` | ESP32 ke broker | Tiap 10 detik |
| `alert` | ESP32 ke broker | Seketika setelah valve ditutup oleh aturan di perangkat |
| `status` | ESP32 ke broker | Saat valve berubah karena tombol fisik, dan sekali saat boot |
| `cmd` | broker ke ESP32 | Saat pemilik menekan buka/tutup di aplikasi |
| `ack` | ESP32 ke broker | Setelah perintah dieksekusi |

```json
// telemetry
{ "msg_id": 18342, "ts": "2026-11-07T07:21:30Z", "flow_lpm": 6.4, "volume_l_delta": 1.07, "valve": "OPEN" }

// alert (rule: CONTINUOUS, STABLE, atau QUIET_HOURS)
{ "msg_id": 18343, "ts": "2026-11-07T07:22:00Z", "rule": "CONTINUOUS", "flow_lpm": 6.4, "valve": "CLOSED" }

// status (source: MANUAL_BUTTON atau BOOT)
{ "msg_id": 18344, "ts": "2026-11-07T07:30:10Z", "valve": "OPEN", "source": "MANUAL_BUTTON" }

// cmd
{ "command_id": 512, "action": "OPEN" }

// ack (result: OK atau ERROR)
{ "command_id": 512, "result": "OK", "valve": "OPEN" }
```

Aturan:
1. `msg_id` naik terus per perangkat dan disimpan di NVS, jadi tidak reset setelah reboot. *Backend* memakainya untuk dedup.
2. Pesan dari buffer *offline* dikirim ulang apa adanya dengan `ts` aslinya.
3. Bila NTP belum sinkron, kirim `"ts": null`. *Backend* memakai waktu terima.
4. Perangkat tidak pernah membuka valve sendiri. Valve hanya terbuka lewat `cmd` `OPEN` atau tombol fisik.
5. Perangkat mengabaikan `command_id` yang sudah pernah dieksekusi, tapi tetap mengirim `ack` lagi.
6. Setelah reboot, perangkat memulihkan status valve terakhir dari NVS lalu mengirim `status` dengan `source: BOOT`.
7. *Backend* menganggap `FAILED` bila `ack` tidak datang dalam 15 detik.
8. Perangkat dianggap offline bila tidak ada pesan selama 30 detik (**Usulan**, 3 kali interval telemetri).
9. Aturan di perangkat: aliran terus menerus 45 menit, aliran stabil ±10% selama 5 menit, aliran di atas 1,0 L/menit selama 5 menit pada jam sepi. Aturan anomali 1,5 kali rata-rata ada di *backend*, bukan di perangkat.

## 3. Mobile dan Backend (HTTPS REST)

Basis URL dan token diberikan lewat `--dart-define` (`API_BASE_URL`, `API_TOKEN`), tidak ditulis di kode. Semua *endpoint* kecuali `/health` memakai header `Authorization: Bearer <token>`. Aplikasi *polling* 10 detik untuk layar yang tampil (**Usulan**, sama dengan interval telemetri).

| Endpoint | Fungsi | Layar |
|---|---|---|
| `GET /health` | Cek hidup, tanpa token | Debug |
| `GET /v1/summary` | Total hari ini, bulan ini, 7 hari, tally, alert terbuka | Beranda |
| `GET /v1/rooms` | Semua kamar dengan status | Beranda, Kamar |
| `GET /v1/rooms/{id}` | Satu kamar, metrik, 3 alert terakhir | Detail Kamar |
| `GET /v1/usage?period=daily/monthly&room_id=` | Data grafik | Detail Grafik, Detail Kamar |
| `GET /v1/alerts?status=all/open/resolved&limit=&before=` | Daftar alert | Notifikasi |
| `GET /v1/alerts/{id}` | Detail alert | Sheet detail |
| `GET /v1/rooms/{id}/commands?limit=` | Riwayat perintah | Detail Kamar |
| `POST /v1/rooms/{id}/valve` | Kirim perintah buka/tutup | Confirm Sheet |
| `GET /v1/commands/{id}` | Status satu perintah | Saklar Pending |
| `POST /v1/push-tokens` | Daftarkan token FCM | Saat aplikasi dibuka |

Enum:
1. Status kamar: `NORMAL`, `LEAK`, `CLOSED`, `OFFLINE`.
2. Alert `type`: `LEAK`, `ANOMALY`, `ACTIVITY`. Alert `status`: `OPEN`, `RESOLVED`, `INFO`.
3. Alert `rule`: `CONTINUOUS`, `STABLE`, `QUIET_HOURS`, `DAILY_RATIO`, `MANUAL_BUTTON`.
4. Perintah `source`: `APP`, `AUTO`, `MANUAL_BUTTON`. Perintah `status`: `PENDING`, `SUCCESS`, `FAILED`.

```json
// GET /v1/summary
{
  "today_l": 312.5,
  "month_l": 4812.0,
  "last_7_days_end": "2026-11-07",
  "last_7_days_l": [210.4, 198.2, 240.0, 305.7, 188.9, 276.3, 312.5],
  "tally": { "normal": 1, "closed": 0, "offline": 1 },
  "open_alert_count": 1,
  "latest_open_alert": { "id": 31, "room_id": 1, "room_name": "Kamar 1", "type": "LEAK", "created_at": "2026-11-07T07:22:00Z" }
}

// GET /v1/rooms  (kamar offline: today_l dan flow_lpm bernilai null)
{ "rooms": [
  { "id": 1, "name": "Kamar 1", "status": "NORMAL", "valve": "OPEN", "today_l": 182.4, "flow_lpm": 6.4, "is_highest": true, "last_seen_at": "2026-11-07T07:21:30Z" },
  { "id": 2, "name": "Kamar 2", "status": "OFFLINE", "valve": "OPEN", "today_l": null, "flow_lpm": null, "is_highest": false, "last_seen_at": "2026-11-07T06:50:02Z" }
] }

// GET /v1/rooms/{id}  (menambah metrik dan alert)
{ "room": { "...sama seperti item di /v1/rooms..." }, "month_l": 2410.0, "avg_daily_l": 80.3, "recent_alerts": [ { "...Alert..." } ] }

// Alert
{ "id": 31, "room_id": 1, "room_name": "Kamar 1", "type": "LEAK", "rule": "CONTINUOUS", "status": "OPEN",
  "created_at": "2026-11-07T07:22:00Z", "resolved_at": null, "resolved_by": null, "detail": { "flow_lpm": 6.4, "duration_min": 45 } }

// GET /v1/alerts
{ "items": [ { "...Alert..." } ], "next_before": 28 }

// GET /v1/usage?period=daily
{ "period": "daily", "series": [ { "label": "2026-11-07", "volume_l": 312.5 } ], "total_l": 1731.9, "average_l": 247.4,
  "peak": { "label": "2026-11-04", "volume_l": 305.7 }, "by_room": [ { "room_id": 1, "name": "Kamar 1", "volume_l": 1100.2 } ] }

// POST /v1/rooms/2/valve   (request)
{ "action": "OPEN" }
// respons 202
{ "command_id": 512, "status": "PENDING" }

// GET /v1/commands/512  (juga item di /v1/rooms/{id}/commands)
{ "id": 512, "room_id": 2, "action": "OPEN", "source": "APP", "status": "PENDING", "created_at": "2026-11-07T07:30:00Z", "acked_at": null }

// POST /v1/push-tokens
{ "token": "fcm-token-...", "platform": "android" }   // respons 204
```

Alur kirim perintah valve:
1. Aplikasi memanggil `POST .../valve` dan mendapat `command_id` dengan status `PENDING`. Saklar masuk keadaan *pending*.
2. Aplikasi memanggil `GET /v1/commands/{id}` tiap 1 detik (**Usulan**) sampai statusnya `SUCCESS` atau `FAILED`, maksimal 20 detik.
3. Perubahan valve karena tombol fisik atau aturan otomatis juga masuk daftar perintah, dengan `source` yang sesuai.

Format galat (semua *endpoint*):
```json
{ "error": { "code": "DEVICE_OFFLINE", "message": "Perangkat Kamar 2 sedang offline" } }
```

| Kode | HTTP | Arti |
|---|---|---|
| `UNAUTHORIZED` | 401 | Token salah atau tidak ada |
| `NOT_FOUND` | 404 | Kamar, alert, atau perintah tidak ada |
| `DEVICE_OFFLINE` | 409 | Perintah ditolak karena perangkat offline |
| `COMMAND_IN_PROGRESS` | 409 | Masih ada perintah `PENDING` di kamar itu |
| `INVALID_PAYLOAD` | 422 | Isi permintaan tidak valid |

## 4. Push FCM

Dikirim *backend* ke token yang terdaftar. Payload bertipe `data` sehingga aplikasi yang menampilkan judulnya sendiri.

```json
{ "type": "LEAK", "alert_id": "31", "room_id": "1", "room_name": "Kamar 1", "title": "Kebocoran terdeteksi", "body": "Kamar 1: aliran terus menerus 45 menit. Valve sudah ditutup." }
```

1. `type` bernilai `LEAK` atau `ANOMALY`. Isi `data` selalu string.
2. Mengetuk notifikasi membuka sheet detail alert dengan `alert_id`.
3. Alert `ACTIVITY` (tombol fisik) tidak dikirim push, hanya muncul di daftar Notifikasi (**Usulan**).

## 5. Berkas dan riwayat versi

Berkas di `packages/contracts`: `openapi.json`, `mqtt-device.md`, `schemas/*.json`, `fixtures/*.json`. Setiap fixture divalidasi terhadap skemanya lewat satu tes, dan mobile, *backend*, serta firmware memakai fixture yang sama untuk uji.

| Versi | Tanggal | Perubahan |
|---|---|---|
| 1.0 | 2026-11-07 | Draft pertama |

## 6. Pertanyaan terbuka

1. Jam sepi: tabel aturan di laporan menulis 01:00 sampai 04:00, tapi *flowchart* ESP menulis 00:00 sampai 04:00. Putuskan satu sebelum firmware menulis aturannya.
2. Angka bertanda **Usulan** perlu disetujui tim: batas offline 30 detik, polling 10 detik dan 1 detik, tidak ada push untuk tombol fisik.
3. Daftar *endpoint* disusun ulang dari layar dan user story, jadi bisa beda tipis dari PRD HTTPS yang pertama. Selisihnya dicek saat `openapi.json` ditulis.
4. Simulator kamar 2 dikerjakan siapa? Usulan: salah satu orang firmware, supaya beban *backend* tidak terlalu berat.
