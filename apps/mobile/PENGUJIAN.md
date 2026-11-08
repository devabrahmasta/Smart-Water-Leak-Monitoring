# Pengujian Progres 3

Bahan untuk slide "Demo + hasil uji". Format pedoman: **input → proses → output**, lalu tandai Berhasil/Gagal, dan lampirkan bukti (screenshot HP, potongan log jendela API/Worker/Simulator).

## Persiapan (sekali per sesi)

1. Nyalakan Docker Desktop.
2. Di root proyek: `.\start-dev.ps1 -Scenario normal`. Akan terbuka 3 jendela: API, Worker, Simulator.
3. Sambungkan HP ke Wi-Fi yang sama dengan laptop. Lalu di `apps\mobile`: `.\run-backend.ps1`.
4. Ganti skenario: nyalakan air Kamar 2 dulu di aplikasi kalau sedang mati, tutup **ketiga** jendela, lalu jalankan `start-dev.ps1` lagi dengan skenario lain. Simulator menyimpan status valve, jadi kalau mulai dalam keadaan tertutup, debit tetap 0 dan kebocoran tidak akan terpicu.

Simulator = Kamar 2. `-Accel` mempercepat pemicu kebocoran jadi ±30 detik, jadi tidak perlu menunggu 45 menit atau jam 01.00.

## Skenario dengan backend + simulator

| # | Input | Proses | Output yang diharapkan di aplikasi |
|---|---|---|---|
| 1 | `-Scenario normal` | Simulator kirim telemetry tiap 10 dtk, worker simpan ke Postgres | Kamar 2 Normal, liter "Hari ini" naik, Summary Card biru |
| 2 | `-Scenario leak-continuous -Accel` | Aturan aliran terus menerus terpicu, alat menutup valve, alert LEAK dikirim | ±30 dtk: Beranda merah, banner "Kebocoran di Kamar 2", Room Card merah muda "Belum ditangani", push masuk (bila FCM aktif) |
| 3 | `-Scenario leak-stable -Accel` | Aturan aliran stabil terpicu | Sama seperti #2, penjelasan "deras yang sama terus menerus" di Detail Kamar |
| 4 | `-Scenario quiet-hours -Accel` | Aturan jam sepi terpicu (pemicunya di simulator, tidak cek jam) | Sama seperti #2, penjelasan "antara jam 01.00 dan 04.00" |
| 5 | Lanjutan #2: Detail Kamar 2 → "Sudah aman, nyalakan air" → konfirmasi | `POST /v1/rooms/2/valve` OPEN → MQTT cmd → simulator ACK | Saklar Pending lalu toast "Air Kamar 2 menyala", alert jadi Selesai, Beranda kembali biru |
| 6 | `-Scenario normal`, Kamar 2 → geser saklar → Matikan air | Perintah CLOSE → ACK | Kartu Kamar 2 gelap "Air dimatikan", Riwayat perintah mencatat "Aplikasi". Kamar 1 tetap Offline selama ESP32 belum tersambung |
| 7 | `-Scenario no-ack`, lalu geser saklar Kamar 2 | Backend menunggu ACK 15 dtk → FAILED | Toast "Alat tidak merespons. Coba lagi". Catatan: simulator tetap mengubah valve tanpa ACK, jadi saklar bisa ikut berubah di telemetry berikutnya |
| 8 | `-Scenario offline` | Simulator diam, backend menandai offline setelah 30 dtk | Kamar 2 Offline, "Cek listrik dan WiFi kamar", saklar tidak bisa disentuh |
| 9 | Tutup jendela Simulator, lalu di root: `python -m services.simulator.main --button` | Event tombol fisik membalik status valve | Saat valve dibuka: alert Aktivitas "Air Kamar 2 dinyalakan · Tombol di alat". **Saat valve ditutup: gagal di backend**, `CommandAction("CLOSED")` tidak valid di `handle_status` |

## Mode demo (tanpa backend, cadangan bila Wi-Fi bermasalah)

Beranda → ikon tabung di kanan atas → **Mode demo**.

| Input | Output |
|---|---|
| Pilih "Kamar 2 bocor" | Beranda merah, Detail Kamar 2 berisi penjelasan dan langkah |
| "Kirim notifikasi bocor" lalu keluar dari aplikasi | 5 dtk kemudian notifikasi "Kebocoran terdeteksi" masuk. Mengetuknya membuka Detail Kamar 2 |
| Pilih "Kamar 2 offline" / "Alat tidak merespons" | Sama seperti #8 / #7 tanpa menunggu |
| Pilih "Data asli dari alat" | Kembali ke backend |

## Push FCM (belum pernah dites)

1. Firebase Console → project `siagatani-ea8a5` → **Add app → Android** → package `id.timunmania.smart_water`. Download `google-services.json`, tapi **jangan** taruh di repo.
2. Dari file itu, isi 4 baris di `.env` (root, sudah di-ignore git):
   ```
   FIREBASE_API_KEY=<client[0].api_key[0].current_key>
   FIREBASE_APP_ID=<client[0].client_info.mobilesdk_app_id>
   FIREBASE_SENDER_ID=<project_info.project_number>
   FIREBASE_PROJECT_ID=siagatani-ea8a5
   ```
3. `.\run-backend.ps1` → harus muncul `==> Push FCM aktif`. Izinkan notifikasi di HP.
4. Cek token terdaftar: jendela API menampilkan `POST /v1/push-tokens 204`.
5. Jalankan skenario #2, lalu keluar dari aplikasi. Notifikasi masuk ±30 dtk. Di jendela Worker tidak boleh ada `[FCM Dry-Run/Mock]` (artinya service account tidak terbaca).
6. Ketuk notifikasi: aplikasi membuka Detail Kamar yang bocor, berisi penjelasan dan langkah penanganan.

## Belum bisa diuji

- ESP32 asli: `firmware/esp32/esp32.ino` sudah ada, tapi belum diuji bersama aplikasi. Pastikan sertifikat broker berlaku untuk IP laptop.
