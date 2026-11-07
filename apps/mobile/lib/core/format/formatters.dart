import 'package:intl/intl.dart';

/// Format tampilan Indonesia (DESIGN.md bagian 3, AGENTS.md Konvensi).
/// Kontrak hanya membawa angka mentah dan waktu UTC; semua format di sini.
///
/// Fungsi tanggal butuh `initializeDateFormatting('id_ID')` (dipanggil di
/// `main.dart`).

const _locale = 'id_ID';

/// WIB = UTC+7 tanpa daylight saving, jadi cukup offset tetap.
const wibOffset = Duration(hours: 7);

final _number = NumberFormat.decimalPattern(_locale)
  ..minimumFractionDigits = 0
  ..maximumFractionDigits = 1;

/// `4812` → `4.812`, `182.4` → `182,4`, `230.0` → `230`.
String formatNumber(num value) => _number.format(value);

/// `4812` → `4.812 L`.
String formatLiters(num value) => '${formatNumber(value)} L';

/// `6.4` → `6,4 L/menit`.
String formatFlow(num value) => '${formatNumber(value)} L/menit';

/// `1.7` → `1,7×`.
String formatRatio(num value) => '${formatNumber(value)}×';

/// Waktu UTC ke jam dinding WIB.
DateTime toWib(DateTime time) => time.toUtc().add(wibOffset);

/// `14.20` (WIB).
String formatClock(DateTime time) =>
    DateFormat('HH.mm', _locale).format(toWib(time));

/// `Jumat, 6 November` (WIB). Dipakai di header Beranda.
String formatDayDate(DateTime time) =>
    DateFormat('EEEE, d MMMM', _locale).format(toWib(time));

/// `5 Nov` (WIB).
String formatShortDate(DateTime time) =>
    DateFormat('d MMM', _locale).format(toWib(time));

/// Umur data relatif: `10 detik lalu`, `3 menit lalu`, `2 jam lalu`,
/// lebih dari sehari jadi tanggal pendek.
String formatAgo(DateTime time, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).toUtc().difference(time.toUtc());
  if (diff.inSeconds < 1) return 'baru saja';
  if (diff.inMinutes < 1) return '${diff.inSeconds} detik lalu';
  if (diff.inHours < 1) return '${diff.inMinutes} menit lalu';
  if (diff.inDays < 1) return '${diff.inHours} jam lalu';
  return formatShortDate(time);
}
