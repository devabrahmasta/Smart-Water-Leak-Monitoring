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
    AlertRule.manualButton => 'Tombol fisik',
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
    'Valve ${a.roomName} ${a.detail['valve'] == 'CLOSED' ? 'ditutup' : 'dibuka'}',
};

String alertSubtitle(Alert a, {DateTime? now}) {
  final when = formatWhen(a.createdAt, now: now);
  return switch (a.type) {
    AlertType.leak => '${ruleLabel(a)} · $when',
    AlertType.anomaly => [a.roomName, _ratio(a), when].nonNulls.join(' · '),
    AlertType.activity => 'Tombol fisik · $when',
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
        title: 'Valve tertutup otomatis',
        subtitle: 'Periksa sebelum membuka',
      );
    case RoomStatus.closed:
      return (title: 'Valve tertutup', subtitle: _dataAge(r, now));
    case RoomStatus.normal:
      return (
        title: r.valve == ValveState.open ? 'Valve terbuka' : 'Valve tertutup',
        subtitle: _dataAge(r, now),
      );
  }
}

String _dataAge(Room r, DateTime? now) => r.lastSeenAt == null
    ? 'Belum ada data'
    : 'Data ${formatAgo(r.lastSeenAt!, now: now)}';

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
    a == CommandAction.open ? 'Buka valve' : 'Tutup valve';

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
