# firmware/esp32

Sketch ESP32 per kamar: YF-S201, relay, *solenoid valve*, tombol fisik.

**Pemilik:** Firmware & hardware (2 orang). **Langkah:** R-13. Ikuti CONTRACT.md bagian 2.

Library: PubSubClient, WiFiClientSecure, ArduinoJson, Preferences (NVS), NTP.

## Wajib

- `msg_id` dan status valve disimpan di NVS, bertahan setelah reboot.
- Saat boot: pulihkan valve dari NVS, kirim `status` dengan `source: BOOT`.
- Valve tidak pernah dibuka otomatis.
- TLS dengan `setCACert`. `setInsecure()` dilarang.
- Konversi debit: L/menit = pulsa per detik ÷ 7,5 (kalibrasi sebelum demo).

## Rahasia

Salin `secrets.example.h` menjadi `secrets.h` lalu isi. `secrets.h` sudah di `.gitignore`.

## Keputusan Hardware & Rangkaian (R-13)

- **Board**: ESP32 Dev Module
- **Relay & Valve**: Logika Normally Closed (NC). Terminal kabel solenoid dihubungkan ke COM & NC.
  - Normal (Air Terbuka): Relay OFF (jalur NC tersambung).
  - Bocor / Tutup: Relay ON (memutus kontak NC).
- **Pinout GPIO**:
  - Flow Sensor (YF-S201): `GPIO 4`
  - Relay Valve: `GPIO 13`
  - Manual Push Button: `GPIO 18` (1x klik untuk membuka valve darurat)
  - LED Merah (Bocor/Tutup): `GPIO 23`
  - LED Hijau (Normal/Buka): `GPIO 33`
  - LED Biru (Status Koneksi WiFi/MQTT): `GPIO 22`
- **Jam Sepi**: 01.00 s.d. 04.00 WIB (flow > 1.0 L/menit selama >= 5 menit).
