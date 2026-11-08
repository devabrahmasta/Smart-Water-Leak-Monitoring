# Backlog mobile (setelah Presentasi Progres 3)

Ditunda supaya presentasi tetap mengikuti kontrak yang sekarang. Dikerjakan setelah presentasi, sebagian butuh perubahan backend dan kontrak.

## Disetujui, menunggu backend

- [ ] **Buka valve ≠ kebocoran selesai.** Alert LEAK tetap Aktif sampai pemilik menekan "Tandai sudah diperbaiki" (`POST /v1/alerts/{id}/resolve`, sudah ada di backend tapi belum tercatat di kontrak). Backend perlu menghapus resolve otomatis saat OPEN dan tombol fisik (`services/api/app/mqtt/handlers.py`). Ubah CONTRACT.md + PRD US-08, US-10.
- [ ] **Push membuka Detail Kamar yang bocor**, bukan sheet detail alert. Ubah CONTRACT.md 4.2.

## Usulan revisi tampilan

- [ ] Rata-rata **mingguan** (rata-rata harian × 7) di Detail Kamar dan Detail Grafik. Beda dari PRD US-06.
- [ ] Kebocoran terasa genting: gradien + Summary Card merah selama ada LEAK aktif (biru lagi setelah semua selesai), gradien merah di Detail Kamar yang bocor, Room Card bocor berlatar `danger-soft`. Perlu update DESIGN.md + Figma.
- [ ] Kalimat ringkasan untuk orang awam di Room Card + status "Belum ditangani / Sudah ditangani".
- [ ] Detail Kamar yang bocor: "Kenapa terdeteksi bocor" + "Yang sebaiknya dilakukan" + tombol Buka valve dan Tandai sudah diperbaiki.
- [ ] Halaman Pengaturan (ikon ⚙ di Beranda): aturan deteksi default (hanya baca) + Mode demo (Normal, Bocor, Offline, Tanpa ACK) dengan notifikasi lokal.
- [ ] Perbaikan bahasa (UX writing) di semua layar. Putuskan istilah "valve" vs "keran utama".

## Perbaikan kecil yang sudah dikerjakan (ada di git stash)

`git stash list` → "mobile/polish: splash+status bar, toast fix, ...". Pasang dengan `git stash pop`.

- Garis bawah kuning ganda di toast (toast tanpa `Material`)
- Layar pembuka dan status bar mengikuti tema
- Sheet bisa di-scroll saat teks diperbesar
- Alert di Detail Kamar tanpa tombol "Lihat kamar"
- Tes ukuran teks 1,3× dan 1,6×

## Lainnya

- [ ] `start-dev.ps1` dukung `-Accel` (simulator `--accel`, kebocoran ±30 detik).
- [ ] README backend: perintah seed yang benar `python -m app.seed`.
