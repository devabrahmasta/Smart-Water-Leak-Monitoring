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
