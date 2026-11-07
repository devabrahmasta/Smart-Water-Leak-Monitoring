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

## Belum diputuskan

- Jam sepi 00.00 atau 01.00 s.d. 04.00 (CONTRACT.md 6.1).
- Relay NC atau NO (PRD 6.3).
