import '../../components/components.dart';
import '../../data/models/models.dart';
import '../format/formatters.dart';

/// Pemetaan model kontrak → isi komponen. Satu tempat untuk semua teks
/// tampilan supaya layar tetap tipis dan mudah dites.

/// "Hari ini 02.14", "Kemarin 21.00", "3 Nov 01.40" (WIB).
String formatWhen(DateTime time, {DateTime? now}) {
  final t = toWib(time);
  final n = toWib(now ?? DateTime.now());
  final today = DateTime.utc(n.year, n.month, n.day);
  final day = DateTime.utc(t.year, t.month, t.day);
  final diff = today.difference(day).inDays;
  final clock = formatClock(time);
  if (diff == 0) return 'Hari ini $clock';
  if (diff == 1) return 'Kemarin $clock';
  return '${formatShortDate(time)} $clock';
}

String ruleLabel(Alert a) {
  final minutes = a.detail['duration_min'];
  return switch (a.rule) {
    AlertRule.continuous =>
      'Aliran terus menerus${minutes != null ? ' $minutes menit' : ''}',
    AlertRule.stable =>
      'Aliran stabil${minutes != null ? ' $minutes menit' : ''}',
    AlertRule.quietHours => 'Aliran jam sepi',
    AlertRule.dailyRatio => 'Pemakaian di atas rata rata',
    AlertRule.manualButton => 'Tombol di alat',
  };
}

String? _ratio(Alert a) {
  final r = a.detail['ratio'];
  return r is num ? '${formatRatio(r)} rata rata' : null;
}

String alertTitle(Alert a) => switch (a.type) {
  AlertType.leak => 'Kebocoran di ${a.roomName}',
  AlertType.anomaly => 'Pemakaian tidak wajar',
  AlertType.activity =>
    'Air ${a.roomName} ${a.detail['valve'] == 'CLOSED' ? 'dimatikan' : 'dinyalakan'}',
};

String alertSubtitle(Alert a, {DateTime? now}) {
  final when = formatWhen(a.createdAt, now: now);
  return switch (a.type) {
    AlertType.leak => '${ruleLabel(a)} · $when',
    AlertType.anomaly => [a.roomName, _ratio(a), when].nonNulls.join(' · '),
    AlertType.activity => 'Tombol di alat · $when',
  };
}

AlertItemType alertItemType(AlertType t) => switch (t) {
  AlertType.leak => AlertItemType.leak,
  AlertType.anomaly => AlertItemType.anomaly,
  AlertType.activity => AlertItemType.activity,
};

AlertItemStatus alertItemStatus(AlertStatus s) => switch (s) {
  AlertStatus.open => AlertItemStatus.open,
  AlertStatus.resolved => AlertItemStatus.resolved,
  AlertStatus.info => AlertItemStatus.info,
};

RoomCardStatus roomCardStatus(RoomStatus s) => switch (s) {
  RoomStatus.normal => RoomCardStatus.normal,
  RoomStatus.leak => RoomCardStatus.leak,
  RoomStatus.closed => RoomCardStatus.closed,
  RoomStatus.offline => RoomCardStatus.offline,
};

/// Teks panel valve di Room Card.
({String title, String subtitle}) valvePanelText(Room r, {DateTime? now}) {
  switch (r.status) {
    case RoomStatus.offline:
      return (
        title: 'Kontrol tidak tersedia',
        subtitle: r.lastSeenAt == null
            ? 'Belum pernah terhubung'
            : 'Terakhir terlihat ${formatClock(r.lastSeenAt!)}',
      );
    case RoomStatus.leak:
      return (
        title: 'Air dihentikan otomatis',
        subtitle: 'Cek keran dan pipa dulu',
      );
    case RoomStatus.closed:
      return (title: 'Air dimatikan', subtitle: _dataAge(r, now));
    case RoomStatus.normal:
      return (
        title: r.valve == ValveState.open ? 'Air menyala' : 'Air dimatikan',
        subtitle: _dataAge(r, now),
      );
  }
}

String _dataAge(Room r, DateTime? now) => r.lastSeenAt == null
    ? 'Belum ada data'
    : 'Data ${formatAgo(r.lastSeenAt!, now: now)}';

/// Kalimat ringkas di Room Card supaya pemilik kos langsung paham keadaan
/// kamar tanpa membaca angka.
String roomSummary(Room r, {DateTime? now}) {
  final today = r.todayL == null
      ? null
      : 'Hari ini terpakai ${formatLiters(r.todayL!.round())}.';
  switch (r.status) {
    case RoomStatus.leak:
      return 'Air mengalir terus tanpa berhenti, kemungkinan ada keran atau '
          'pipa bocor. Air sudah dihentikan otomatis. Belum ditangani.';
    case RoomStatus.offline:
      return r.lastSeenAt == null
          ? 'Alat di kamar ini belum pernah mengirim data. Cek listrik dan WiFi kamar.'
          : 'Alat di kamar ini tidak mengirim data sejak '
                '${formatWhen(r.lastSeenAt!, now: now)}. Cek listrik dan WiFi kamar.';
    case RoomStatus.closed:
      return ['Air di kamar ini sedang dimatikan.', ?today].join(' ');
    case RoomStatus.normal:
      final flowing = (r.flowLpm ?? 0) > 0;
      return [
        flowing ? 'Air sedang dipakai.' : 'Tidak ada air yang mengalir.',
        ?today,
      ].join(' ');
  }
}

/// "5 detik", "45 menit", "1 jam 30 menit", "1 menit 30 detik".
String formatDuration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = seconds % 3600 ~/ 60;
  final rest = seconds % 60;
  return [
    if (hours > 0) '$hours jam',
    if (minutes > 0) '$minutes menit',
    if (rest > 0 || seconds == 0) '$rest detik',
  ].join(' ');
}

/// `01:00`, `04:00` menjadi "01.00 sampai 04.00".
String formatQuietRange(String start, String end) =>
    '${start.replaceAll(':', '.')} sampai ${end.replaceAll(':', '.')}';

/// Penjelasan kebocoran di Detail Kamar. Durasi memakai ambang kamar itu,
/// atau nilai bawaan CONTRACT.md 2.9 bila belum dimuat.
({String why, List<String> steps}) leakExplanation(
  Alert a, {
  RoomRules? rules,
}) {
  final minutes = a.detail['duration_min'];
  final flow = a.detail['flow_lpm'];
  final flowText = flow is num ? ' sekitar ${formatFlow(flow)}' : '';
  String limit(int? sec, int fallback) => minutes is num
      ? formatDuration((minutes * 60).round())
      : formatDuration(sec ?? fallback);
  final why = switch (a.rule) {
    AlertRule.continuous =>
      'Air mengalir$flowText tanpa berhenti melewati batas '
          '${limit(rules?.continuousSec, 2700)} yang diatur untuk kamar ini.',
    AlertRule.stable =>
      'Air mengalir$flowText dengan deras yang sama melewati batas '
          '${limit(rules?.stableSec, 300)} yang diatur untuk kamar ini. Bisa '
          'jadi keran belum tertutup atau pipa bocor, bisa juga pemakaian '
          'yang memang lama.',
    AlertRule.quietHours =>
      'Ada air mengalir$flowText melewati batas '
          '${limit(rules?.quietSec, 300)} pada jam sepi '
          '${formatQuietRange(rules?.quietStart ?? '01:00', rules?.quietEnd ?? '04:00')}.',
    AlertRule.manualButton => 'Air dihentikan lewat tombol di alat kamar.',
    AlertRule.dailyRatio => 'Pemakaian hari ini jauh di atas biasanya.',
  };
  return (
    why: '$why Untuk berjaga-jaga, alat menghentikan air secara otomatis.',
    steps: const [
      'Cek keran kamar mandi, wastafel, dan kloset. Pastikan semua tertutup.',
      'Lihat pipa dan lantai, apakah ada rembesan atau genangan.',
      'Kalau bocornya dari pipa, panggil tukang sebelum air dinyalakan lagi.',
      'Setelah aman, nyalakan air lewat tombol di bawah. Kebocoran otomatis ditandai selesai.',
    ],
  );
}

ValveSwitchState valveSwitchState(Room r) {
  if (r.status == RoomStatus.offline) return ValveSwitchState.disabled;
  return r.valve == ValveState.open
      ? ValveSwitchState.on
      : ValveSwitchState.off;
}

/// Urutan "Perlu dicek" di Beranda: Bocor, Offline, Tertutup (US-02).
List<Room> roomsNeedingAttention(List<Room> rooms) {
  const order = {
    RoomStatus.leak: 0,
    RoomStatus.offline: 1,
    RoomStatus.closed: 2,
  };
  return rooms.where((r) => order.containsKey(r.status)).toList()
    ..sort((a, b) => order[a.status]!.compareTo(order[b.status]!));
}

CommandSource commandSource(CommandSourceType s) => switch (s) {
  CommandSourceType.app => CommandSource.app,
  CommandSourceType.auto => CommandSource.auto,
  CommandSourceType.manualButton => CommandSource.manualButton,
};

CommandResult commandResult(CommandStatus s) => switch (s) {
  CommandStatus.success => CommandResult.success,
  CommandStatus.pending => CommandResult.pending,
  CommandStatus.failed => CommandResult.failed,
};

String commandActionLabel(CommandAction a) =>
    a == CommandAction.open ? 'Nyalakan air' : 'Matikan air';

/// Sumbu x grafik: `2026-11-07` → `7`, `2026-10` → `Okt`.
String usageAxisLabel(UsagePoint p, UsagePeriod period) {
  final parts = p.label.split('-');
  if (period == UsagePeriod.daily) return int.parse(parts[2]).toString();
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  return months[int.parse(parts[1]) - 1];
}

/// Keterangan rentang di kanan atas grafik.
String usageRangeLabel(Usage u) {
  if (u.series.isEmpty) return '';
  final first = usageAxisLabel(u.series.first, u.period);
  final last = usageAxisLabel(u.series.last, u.period);
  if (u.period == UsagePeriod.monthly) return '$first sampai $last';
  final month = usageAxisLabel(
    UsagePoint(label: u.series.last.label.substring(0, 7), volumeL: 0),
    UsagePeriod.monthly,
  );
  return first == last ? '$first $month' : '$first sampai $last $month';
}

List<ChartPoint> chartPoints(Usage u) => [
  for (final p in u.series)
    ChartPoint(label: usageAxisLabel(p, u.period), liters: p.volumeL),
];

/// Nama bulan penuh untuk Metric Tile ("Total November").
String monthName(DateTime time) {
  const names = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];
  return names[toWib(time).month - 1];
}
