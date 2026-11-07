/// Konfigurasi dari `--dart-define` (CONTRACT.md bagian 3).
/// URL dan token tidak boleh ditulis di kode atau repo.
///
/// ```
/// flutter run --dart-define=USE_MOCK=false \
///   --dart-define=API_BASE_URL=http://10.0.2.2:8000 \
///   --dart-define=API_TOKEN=<token>
/// ```
abstract final class Env {
  /// `true` (default): data dari fixture kontrak, tanpa backend.
  static const useMock = bool.fromEnvironment('USE_MOCK', defaultValue: true);

  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const apiToken = String.fromEnvironment('API_TOKEN');

  /// Nama pemilik di header Beranda. MVP tanpa login (PRD 2.3).
  static const ownerName = String.fromEnvironment(
    'OWNER_NAME',
    defaultValue: 'Pak Hendra',
  );
  static const propertyName = String.fromEnvironment(
    'PROPERTY_NAME',
    defaultValue: 'Kos Melati',
  );
}
