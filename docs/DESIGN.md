# DESIGN.md  Smart Water (aplikasi pemilik kos)

Sumber kebenaran tunggal untuk UI mobile. Semua layar dan komponen Figma mengikuti file ini. Kalau ada yang bentrok, file ini yang menang.

## 1. Arah desain

Modern, ringan, padat informasi tapi lega. Acuan visual: kartu berwarna solid dengan teks gelap (referensi panel surya), kartu perangkat dengan saklar (referensi smart home), kartu bertint lembut dan nav melayang (referensi kesehatan).

Prinsip:
1. Tanpa border sama sekali. Pemisah objek memakai beda warna permukaan, bukan garis.
2. Satu radius kartu untuk semua kartu: 24 px.
3. Biru hanya untuk aksi utama dan data utama. Sisanya monokrom.
4. Status selalu ditulis dengan teks dan ikon, warna hanya penguat.
5. Satu aksi utama per layar.

## 2. Warna

| Token | Nilai | Pakai untuk |
|---|---|---|
| `bg` | #FFFCF6 | Latar semua layar |
| `surface` | #F2F0EA | Kartu biasa, tile, input |
| `surface-strong` | #E7E4DC | Track saklar mati, bar grafik sekunder, tombol sekunder ditekan |
| `ink` | #16181C | Teks utama, kartu gelap (valve tertutup), nav aktif ikon |
| `ink-muted` | #5F625F | Teks sekunder, label |
| `ink-subtle` | #9B9C97 | Disabled, placeholder, keterangan kecil di atas `bg` |
| `primary` | #3389F1 | Kartu ringkasan, tombol utama, saklar nyala, bar grafik utama |
| `primary-soft` | #DDEBFC | Chip Normal, segmen aktif, latar ikon biru |
| `primary-text` | #1E5FB0 | Teks dan ikon di atas `primary-soft` |
| `on-primary` | #FFFFFF | Semua teks dan ikon di atas `primary` |
| `danger` | #D2392F | Status Bocor, tombol tutup darurat |
| `danger-soft` | #FBE4E1 | Banner peringatan, chip Bocor |
| `danger-text` | #B02A22 | Teks dan ikon di atas `danger-soft` |
| `on-dark` | #FFFCF6 | Teks di atas `ink` |

Catatan kontras:
1. Teks di atas `primary` putih (`on-primary`), kontras 3,5:1. Karena itu teks di atas biru minimal 13 px SemiBold, dan angka besar tetap Display 40.
2. `ink-muted` di atas `surface` 5,4:1 dan di atas `bg` 6,0:1, aman untuk teks 12 px.
3. `primary-text` di atas `primary-soft` 5,2:1, `danger-text` di atas `danger-soft` 5,4:1.
4. `ink-subtle` cuma 2,7:1, jadi hanya untuk elemen disabled, tidak untuk teks yang harus dibaca.
5. `danger` adalah satu-satunya warna semantik tambahan. Dipakai hanya untuk kebocoran.

## 3. Tipografi

Satu keluarga: **Plus Jakarta Sans** (Google Fonts), angka pakai `tabular-nums`.

| Gaya | Ukuran / tinggi baris | Berat | Pakai untuk |
|---|---|---|---|
| Display | 40 / 44 | 700 | Angka utama kartu ringkasan |
| Title | 22 / 28 | 700 | Judul layar |
| Headline | 17 / 24 | 600 | Nama kamar, judul kartu |
| Body | 15 / 22 | 500 | Teks isi |
| Label | 13 / 18 | 600 | Chip, tombol kecil, label angka |
| Caption | 12 / 16 | 500 | Waktu, satuan, keterangan |

Satuan (L, L/menit) ditulis lebih kecil di samping angka, berat 600, warna `ink-muted`. Format angka Indonesia: 4.812 L, 6,4 L/menit.

## 4. Bentuk, jarak, bayangan

Radius:
1. `radius-card` 24: semua kartu, sheet, banner, nav melayang.
2. `radius-pill` 999: tombol, chip, segmented control, saklar.
3. Lingkaran: wadah ikon dan avatar.
Tidak ada radius lain.

Jarak (kelipatan 4): 4, 8, 12, 16, 20, 24, 32.
1. Gutter layar 20.
2. Padding dalam kartu 20.
3. Jarak antar kartu 12.
4. Jarak antar seksi 24.

Bayangan: hanya dua.
1. `shadow-float`: 0 8 24 rgba(22,24,28,0.10), untuk nav melayang, sheet, toast.
2. Kartu biasa tanpa bayangan. Pemisah cukup `surface` di atas `bg`.

Ikon: Lucide, stroke 1.75, ukuran 20 (dalam teks) dan 24 (nav). Wadah ikon lingkaran 40.

Sentuhan: semua target minimal 44 x 44. Tekan = skala 0,97 plus warna satu tingkat lebih gelap, 150 ms.

## 5. Navigasi

Nav bawah melayang berbentuk pil, 3 tab: **Beranda, Kamar, Notifikasi**. Grafik dibuka dari link "Lihat grafik" di Summary Card. Tab aktif = pil `primary` berisi ikon dan label. Tab lain ikon plus label `ink-muted`. Badge jumlah alert aktif di Notifikasi memakai `danger`.

Tab Profil dihapus karena tidak ada login. Nama pemilik tampil di header Beranda.

## 6. Komponen

Setiap komponen dibuat sebagai Figma component dengan variant. Layar hanya boleh menyusun komponen ini.

| Komponen | Variant | Isi |
|---|---|---|
| Button | primary, secondary, danger · L 52, M 44 · default, pressed, disabled, loading | Label, ikon opsional di kiri |
| Valve Switch | on, off, pending, disabled | Saklar 52 x 32, label status di kiri |
| Status Chip | Normal, Bocor, Valve tertutup, Offline | Ikon 14 + label |
| Segmented Control | 2 atau 3 segmen | Harian/Bulanan, Semua/Kamar 1/Kamar 2, Semua/Aktif/Selesai |
| Screen Header | home, sub | home: sapaan + tanggal + lonceng. sub: tombol kembali + judul |
| Summary Card | satu | Kartu `primary`: total hari ini (Display), bulan ini, 7 bar mini harian |
| Status Tally | satu | 3 angka dalam satu kartu `surface`: Normal, Tertutup, Offline |
| Alert Banner | leak, anomaly | Kartu `danger-soft`, ikon, judul, kamar, waktu, tombol Lihat |
| Room Card | normal, leak, closed, offline · tertinggi on/off | Nama, chip, liter hari ini, debit, Valve Switch |
| Metric Tile | satu | Label + angka + satuan, untuk Detail Kamar dan Grafik |
| Usage Chart Card | daily, monthly | Bar chart, nilai puncak ditandai, tap menampilkan nilai |
| Room Compare Row | satu | Nama kamar, bar proporsi, liter |
| Alert Item | open, resolved · leak, anomaly | Ikon, judul, kamar, aturan, waktu, chip status |
| Command Row | success, pending, failed | Aksi, sumber, waktu, hasil |
| Confirm Sheet | close, open | Judul, penjelasan, 2 tombol |
| Toast | success, error | Ikon + teks satu baris |
| Bottom Nav | 3 tab aktif bergantian · badge on/off | Pil melayang |

Aturan status kamar:
1. Normal: kartu `surface`, chip Normal (`primary-soft`).
2. Bocor: kartu `surface`, chip Bocor (`danger-soft` + ikon peringatan), valve otomatis off.
3. Valve tertutup manual: kartu `ink`, teks `on-dark`. Ini satu-satunya kartu gelap, jadi kamar yang airnya mati langsung kelihatan.
4. Offline: angka diganti "Tidak ada data", saklar disabled, chip Offline (`surface-strong`).

## 7. Isi layar

Beranda: Header, Summary Card (link Lihat grafik), Alert Banner (hanya kalau ada alert aktif), Status Tally, "Perlu dicek" berisi Room Card yang Bocor, Tertutup, atau Offline. Kalau kosong, Empty State.

Detail Grafik (dari Beranda): Header sub, Segmented Harian/Bulanan, Usage Chart Card, 2 Metric Tile (total, rata rata), Room Compare.

Kamar: Header, Segmented Semua/Perlu dicek/Offline, satu Room Card per kamar. Tap kartu ke Detail Kamar.

Detail Kamar: Header sub, Room Card, 2 Metric Tile (bulan ini, rata rata harian), Usage Chart Card kamar ini, Command Row, Alert Item terakhir. Kontrol valve lewat saklar di Room Card, lalu Confirm Sheet.

Notifikasi: Header, Segmented Semua/Aktif/Selesai, daftar Alert Item. Detail alert dibuka sebagai sheet berisi aturan yang terpicu dan tombol Buka valve.

## 8. Larangan

1. Border, outline, dan garis pembagi dalam bentuk apa pun.
2. Radius selain 24, pil, dan lingkaran.
3. Gradien, glassmorphism, dan glow. Satu pengecualian: Beranda punya gradien biru di belakang header (primary 55% di atas, 16% di 45%, 0% di bawah, tinggi 340). Layar lain tetap polos.
4. Emoji sebagai ikon.
5. Teks di atas biru yang lebih kecil dari 13 px atau lebih tipis dari SemiBold.
6. Bayangan pada kartu biasa.
7. Ilustrasi dekoratif yang tidak membawa informasi.
8. Mengubah gaya komponen di level layar. Kalau butuh beda, tambah variant.
