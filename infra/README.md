# infra

Postgres 16 + Mosquitto 2 (TLS 8883) untuk pengembangan lokal.

**Pemilik:** Backend. **Langkah:** R-00.

## Persiapan sekali

1. **Sertifikat TLS** di `mosquitto/certs/` (tidak di-commit): `ca.crt`, `server.crt`, `server.key`. CN/SAN server harus sama dengan host yang dipakai ESP32 (lihat PRD 6.5 soal hosting).
2. **ACL:** salin `mosquitto/acl.example` menjadi `mosquitto/acl`.
3. **Akun:** buat `mosquitto/passwd` untuk `backend`, `1`, dan `2`:

   ```bash
   docker run --rm -it -v "$PWD/infra/mosquitto:/m" eclipse-mosquitto:2 mosquitto_passwd -c /m/passwd backend
   docker run --rm -it -v "$PWD/infra/mosquitto:/m" eclipse-mosquitto:2 mosquitto_passwd /m/passwd 1
   docker run --rm -it -v "$PWD/infra/mosquitto:/m" eclipse-mosquitto:2 mosquitto_passwd /m/passwd 2
   ```

4. `make dev` dari root.

Kriteria selesai R-00: `mosquitto_pub` dengan TLS ke port 8883 berhasil.
