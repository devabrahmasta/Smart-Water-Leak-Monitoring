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

## Cara Menjalankan di Arduino IDE

1. Buka Arduino IDE.
2. Install library via **Library Manager** (`Ctrl+Shift+I`):
   - `PubSubClient` (oleh Nick O'Leary)
   - `ArduinoJson` (oleh Benoit Blanchon)
3. Buat file `firmware/esp32/secrets.h` (salin dari `secrets.example.h`), lalu isi:
   - SSID & Password WiFi
   - Host MQTT, port, kredensial (`MQTT_DEVICE_ID`: `"1"` untuk kamar 1, `"2"` untuk kamar 2)
   - Sertifikat CA broker di `MQTT_CA_CERT`
4. Buka file `firmware/esp32/esp32.ino`.
5. Pilih Board: **ESP32 Dev Module**, port COM yang sesuai, lalu klik **Upload**.

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
- **Jam Sepi**: bawaan 01.00 s.d. 04.00 WIB (flow > 1.0 L/menit selama >= 5 menit). Rentang dan durasi semua aturan bisa diubah per kamar dari aplikasi.

## Log serial dua ESP32 sekaligus

Kamar 1 dan Kamar 2 masing-masing satu ESP32 (`MQTT_DEVICE_ID` `"1"` dan `"2"` di `secrets.h`; Kamar 2 tanpa valve, kodenya sama). Untuk melihat log keduanya di satu terminal dan menyimpannya ke `logs/serial/`:

```bash
pip install -r firmware/esp32/tools/requirements.txt
python firmware/esp32/tools/serial_monitor.py --list
python firmware/esp32/tools/serial_monitor.py --port COM3=Kamar1 --port COM5=Kamar2
```

Tutup Serial Monitor Arduino IDE dulu, dan hentikan skrip (Ctrl+C) sebelum upload sketch. Log Kamar 3 ada di jendela simulator, dan alert dari semua kamar tercatat di jendela Worker (`[device N] KEBOCORAN ...`).
