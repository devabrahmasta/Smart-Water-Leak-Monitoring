# apps/mobile

Aplikasi Android Flutter untuk pemilik kos.

**Pemilik:** Mobile. **Langkah:** R-09 s.d. R-12.

## Mulai

Proyek Flutter belum dibuat. Jalankan dari folder ini:

```bash
flutter create --org id.timunmania --project-name smart_water --platforms android .
```

Lalu susun `lib/` seperti PRD 4.2:

```
lib/
├── core/         tema dari docs/DESIGN.md, router, dio client, format angka id_ID
├── components/   1 file per komponen Figma
├── features/     home, usage, rooms, room_detail, alerts
└── data/         model, repository, API
```

Stack: Riverpod, go_router, dio, fl_chart, firebase_messaging.

## Menjalankan

URL dan token tidak boleh ditulis di kode (CONTRACT.md bagian 3):

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000 --dart-define=API_TOKEN=<token>
```

`google-services.json` dari Firebase taruh di `android/app/`, sudah di `.gitignore`.

Sumber visual: Figma *Smart Water UI* (https://www.figma.com/design/BRThPzyDj0I2w2hIrjcnDX).

## Komponen (R-10)

Semua widget komponen Figma ada di `lib/components/`, satu file per komponen, diekspor lewat `components.dart`. Layar hanya boleh menyusun widget dari sana.

Galeri komponen untuk dibandingkan dengan Figma page *Components*: jalankan build debug, lalu tekan tombol **Galeri komponen** di Beranda (rute `/galeri`, tidak ada di build release).

## Data, valve, dan push (R-11, R-12)

| `--dart-define` | Default | Fungsi |
|---|---|---|
| `USE_MOCK` | `true` | Data contoh sesuai kontrak, tanpa backend |
| `MOCK_SCENARIO` | `standard` | `all-normal`, `offline`, `empty`, `no-ack` |
| `API_BASE_URL`, `API_TOKEN` | kosong | Backend asli (`USE_MOCK=false`) |
| `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_SENDER_ID`, `FIREBASE_PROJECT_ID` | kosong | Push FCM. Kosong = push mati, aplikasi tetap jalan |

Nilai Firebase diambil dari Firebase Console → Project settings → aplikasi Android. Tidak perlu `google-services.json`.
