# Backlog mobile (setelah Presentasi Progres 3)

Sebagian revisi sudah dikerjakan untuk demo (lihat bawah). Sisanya butuh perubahan backend atau kontrak, jadi ditunda.

## Disetujui, menunggu backend + kontrak

- [ ] **Buka valve ≠ kebocoran selesai.** Alert LEAK tetap Aktif sampai pemilik menekan "Tandai sudah diperbaiki" (`POST /v1/alerts/{id}/resolve`, sudah ada di backend tapi belum tercatat di kontrak). Backend perlu menghapus resolve otomatis saat OPEN dan tombol fisik (`services/api/app/mqtt/handlers.py`). Ubah CONTRACT.md + PRD US-08, US-10. Setelah itu: status "Sudah ditangani" dan tombol "Tandai sudah diperbaiki" di Leak Guide Card.
- [ ] **CONTRACT.md 4 butir 2 perlu disesuaikan.** Aplikasi sudah membuka Detail Kamar dari `room_id` saat notifikasi diketuk, sedangkan kontrak masih menulis sheet detail alert. Payload dan backend tidak berubah.
- [ ] Halaman Pengaturan: aturan deteksi default (hanya baca). Saat ini penjelasan aturan ada di Leak Guide Card.
- [ ] Figma: sesuaikan Room Card bocor, Summary Card merah, gradien merah, Leak Guide Card, Mode demo (DESIGN.md sudah diperbarui).

## Sudah dikerjakan (branch `mobile/progres3-demo-polish`, kontrak tidak berubah)

- [x] Kebocoran terasa genting: gradien + Summary Card merah selama ada LEAK, Room Card bocor `danger-soft`, gradien merah di Detail Kamar yang bocor
- [x] Kalimat awam di Room Card ("… Belum ditangani.")
- [x] Detail Kamar bocor: "Kenapa terdeteksi bocor" + "Yang sebaiknya dilakukan" + tombol nyalakan air
- [x] Rata-rata mingguan (harian × 7) di Detail Kamar dan Detail Grafik
- [x] Mode demo (ikon tabung di Beranda): keadaan Normal, Bocor, Offline, Tanpa ACK + notifikasi bocor lokal
- [x] UX writing: "valve" → "air" di teks yang dibaca pemilik (Nyalakan/Matikan air, Air dihentikan otomatis, Alat tidak merespons)
- [x] `start-dev.ps1 -Accel`
- [x] Notifikasi diketuk membuka Detail Kamar

## Lainnya

- [ ] README backend: perintah seed yang benar `python -m app.seed`.
- [ ] `.env.example`: `FCM_SERVICE_ACCOUNT_PATH` sebaiknya path absolut. Path relatif dibaca dari folder kerja worker (`services/api`), jadi file tidak ketemu dan FCM diam-diam masuk mode dry-run.
