# MQTT Device Contract

Dokumentasi spesifikasi topik dan payload MQTT antara perangkat (ESP32/Simulator) dan Backend.
Sumber kebenaran: [docs/CONTRACT.md](../../docs/CONTRACT.md) Bagian 2.

## 1. Konvensi Protokol
- **Broker:** Mosquitto (port 8883 over TLS v1.2/v1.3).
- **Format:** JSON UTF-8.
- **Kualitas Layanan (QoS):** QoS 1 untuk semua pesan.
- **Root Topik:** `swm/{device_id}/...` di mana `{device_id}` adalah ID unik perangkat (misal `1` untuk kamar nyata, `2` untuk simulator).
- **Penanganan Offline Buffer:** Pesan dalam buffer offline dikirim ulang dengan `ts` aslinya.
- **Deduplikasi:** `msg_id` bernilai integer positif monoton per perangkat yang disimpan di NVS perangkat agar tahan reboot. Backend menggunakan `msg_id` untuk mencegah pencatatan volume ganda.
- **Waktu (Timestamp):** Format ISO 8601 UTC (contoh: `2026-11-07T07:21:30Z`). Jika NTP belum sinkron, perangkat wajib mengirim `null`, dan backend akan menggunakan `received_at`.

---

## 2. Daftar Topik

| Topik | Arah | Trigger / Frekuensi | Keterangan |
|---|---|---|---|
| `swm/{device_id}/telemetry` | ESP32 → Broker | Tiap 10 detik | Data debit & delta volume periodik |
| `swm/{device_id}/alert` | ESP32 → Broker | Seketika saat valve ditutup oleh aturan perangkat | Kejadian kebocoran |
| `swm/{device_id}/status` | ESP32 → Broker | Saat boot dan saat tombol fisik ditekan | Perubahan posisi valve lokal |
| `swm/{device_id}/cmd` | Broker → ESP32 | Saat pengguna menekan buka/tutup di aplikasi | Perintah kendali valve |
| `swm/{device_id}/ack` | ESP32 → Broker | Setelah perintah `cmd` selesai dieksekusi | Konfirmasi eksekusi perintah |
| `swm/{device_id}/config` | Broker → ESP32 | Saat ambang kamar diubah, *retained* | Durasi aturan dalam detik (1 sampai 86400) dan jam sepi WIB (`HH:MM`), disimpan di NVS |
| `swm/2/demo` | Broker → Simulator | Saat skenario Kamar 2 dipilih di Mode demo | Hanya simulator, tidak untuk perangkat nyata |

---

## 3. Spesifikasi Payload

### 3.1 Telemetry (`swm/{device_id}/telemetry`)
Skema: `schemas/telemetry.json`

```json
{
  "msg_id": 18342,
  "ts": "2026-11-07T07:21:30Z",
  "flow_lpm": 6.4,
  "volume_l_delta": 1.07,
  "valve": "OPEN"
}
```

### 3.2 Alert (`swm/{device_id}/alert`)
Skema: `schemas/alert.json`
- `rule` yang diizinkan di perangkat: `CONTINUOUS`, `STABLE`, atau `QUIET_HOURS`.
- `valve` selalu bernilai `"CLOSED"`.

```json
{
  "msg_id": 18343,
  "ts": "2026-11-07T07:22:00Z",
  "rule": "CONTINUOUS",
  "flow_lpm": 6.4,
  "valve": "CLOSED"
}
```

### 3.3 Status (`swm/{device_id}/status`)
Skema: `schemas/status.json`
- `source`: `MANUAL_BUTTON` atau `BOOT`.

```json
{
  "msg_id": 18344,
  "ts": "2026-11-07T07:30:10Z",
  "valve": "OPEN",
  "source": "MANUAL_BUTTON"
}
```

### 3.4 Command (`swm/{device_id}/cmd`)
Skema: `schemas/cmd.json`
- `action`: `OPEN` atau `CLOSE`.

```json
{
  "command_id": 512,
  "action": "OPEN"
}
```

### 3.5 Acknowledgement (`swm/{device_id}/ack`)
Skema: `schemas/ack.json`
- `result`: `OK` atau `ERROR`.
- `valve`: `OPEN` atau `CLOSED`.

```json
{
  "command_id": 512,
  "result": "OK",
  "valve": "OPEN"
}
```

