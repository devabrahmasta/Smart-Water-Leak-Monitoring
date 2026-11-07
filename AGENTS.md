# AGENTS.md

Wajib dibaca *coding agent* di awal setiap sesi.

## Sumber kebenaran (urut prioritas)

1. `docs/CONTRACT.md` dan `packages/contracts/`
2. `docs/PRD.md`
3. `docs/DESIGN.md` (untuk mobile)
4. Kode yang sudah ada

Kalau kode bertentangan dengan kontrak, kontrak yang benar. Kalau kontraknya yang perlu diubah, **berhenti dan tanya** manusia. Jangan ubah kontrak diam-diam.

## Cara kerja

- Satu sesi = satu langkah PRD (R-00 s.d. R-13, PRD 5.2) = satu cabang.
- Hanya ubah file di jalur langkah itu (mis. R-05 hanya `services/api`).
- Untuk `rules/`, ingest, dan perintah valve: tulis tes dari kriteria selesai dulu, baru kode. Jangan ubah tes supaya lulus.
- Langkah besar (R-07, R-11): tulis rencana file dan fungsi, tunggu persetujuan.
- Commit kecil setiap tes hijau.

## Perintah

- `make dev`: nyalakan Postgres + Mosquitto
- `make test`: jalankan semua tes
- `make contracts`: ekspor `openapi.json`

## Larangan

- Rahasia di repo (`.env`, `secrets.h`, sertifikat, *service account*).
- `setInsecure()` di firmware. Wajib `setCACert`.
- Warna, radius, atau ukuran teks di luar token `docs/DESIGN.md`.
- *Border* di UI.
- Komponen UI baru yang tidak ada di Figma page *Components*.

## Konvensi

- Bahasa UI: Indonesia. Format angka id_ID (`4.812 L`, `6,4 L/menit`).
- Waktu disimpan UTC, ditampilkan Asia/Jakarta. Batas hari rekap = hari WIB.
- Nilai enum huruf besar.
