/// Model REST sesuai CONTRACT.md bagian 3. Nama field JSON mengikuti kontrak
/// persis; jangan ubah tanpa mengubah kontrak.
library;

enum RoomStatus { normal, leak, closed, offline }

enum ValveState { open, closed }

enum AlertType { leak, anomaly, activity }

enum AlertStatus { open, resolved, info }

enum AlertRule { continuous, stable, quietHours, dailyRatio, manualButton }

enum CommandAction { open, close }

enum CommandSourceType { app, auto, manualButton }

enum CommandStatus { pending, success, failed }

enum UsagePeriod { daily, monthly }

T _enum<T extends Enum>(List<T> values, Object? raw) {
  // Kontrak: enum huruf besar dengan garis bawah (QUIET_HOURS).
  final key = (raw as String).toLowerCase().replaceAll('_', '');
  return values.firstWhere((v) => v.name.toLowerCase() == key);
}

T? _enumOrNull<T extends Enum>(List<T> values, Object? raw) =>
    raw == null ? null : _enum(values, raw);

String enumToContract(Enum value) => value.name
    .replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]}')
    .toUpperCase();

DateTime _time(Object? raw) => DateTime.parse(raw as String).toUtc();
DateTime? _timeOrNull(Object? raw) => raw == null ? null : _time(raw);
double _num(Object? raw) => (raw as num).toDouble();
double? _numOrNull(Object? raw) => raw == null ? null : _num(raw);

class AlertRef {
  const AlertRef({
    required this.id,
    required this.roomId,
    required this.roomName,
    required this.type,
    required this.createdAt,
  });

  factory AlertRef.fromJson(Map<String, dynamic> j) => AlertRef(
    id: j['id'] as int,
    roomId: j['room_id'] as int,
    roomName: j['room_name'] as String,
    type: _enum(AlertType.values, j['type']),
    createdAt: _time(j['created_at']),
  );

  final int id;
  final int roomId;
  final String roomName;
  final AlertType type;
  final DateTime createdAt;
}

/// `GET /v1/summary`.
class Summary {
  const Summary({
    required this.todayL,
    required this.monthL,
    required this.last7DaysEnd,
    required this.last7DaysL,
    required this.tallyNormal,
    required this.tallyClosed,
    required this.tallyOffline,
    required this.openAlertCount,
    required this.latestOpenAlert,
  });

  factory Summary.fromJson(Map<String, dynamic> j) {
    final tally = j['tally'] as Map<String, dynamic>;
    final latest = j['latest_open_alert'];
    return Summary(
      todayL: _num(j['today_l']),
      monthL: _num(j['month_l']),
      last7DaysEnd: j['last_7_days_end'] as String,
      last7DaysL: [for (final v in j['last_7_days_l'] as List) _num(v)],
      tallyNormal: tally['normal'] as int,
      tallyClosed: tally['closed'] as int,
      tallyOffline: tally['offline'] as int,
      openAlertCount: j['open_alert_count'] as int,
      latestOpenAlert: latest == null
          ? null
          : AlertRef.fromJson(latest as Map<String, dynamic>),
    );
  }

  final double todayL;
  final double monthL;
  final String last7DaysEnd;
  final List<double> last7DaysL;
  final int tallyNormal;
  final int tallyClosed;
  final int tallyOffline;
  final int openAlertCount;
  final AlertRef? latestOpenAlert;
}

/// Item `GET /v1/rooms`.
class Room {
  const Room({
    required this.id,
    required this.name,
    required this.status,
    required this.valve,
    required this.todayL,
    required this.flowLpm,
    required this.isHighest,
    required this.lastSeenAt,
  });

  factory Room.fromJson(Map<String, dynamic> j) => Room(
    id: j['id'] as int,
    name: j['name'] as String,
    status: _enum(RoomStatus.values, j['status']),
    valve: _enum(ValveState.values, j['valve']),
    todayL: _numOrNull(j['today_l']),
    flowLpm: _numOrNull(j['flow_lpm']),
    isHighest: j['is_highest'] as bool? ?? false,
    lastSeenAt: _timeOrNull(j['last_seen_at']),
  );

  final int id;
  final String name;
  final RoomStatus status;
  final ValveState valve;

  /// Null saat offline.
  final double? todayL;
  final double? flowLpm;
  final bool isHighest;

  /// Null bila perangkat belum pernah terhubung (US-18).
  final DateTime? lastSeenAt;
}

/// `GET /v1/rooms/{id}`.
class RoomDetail {
  const RoomDetail({
    required this.room,
    required this.monthL,
    required this.avgDailyL,
    required this.recentAlerts,
  });

  factory RoomDetail.fromJson(Map<String, dynamic> j) => RoomDetail(
    room: Room.fromJson(j['room'] as Map<String, dynamic>),
    monthL: _numOrNull(j['month_l']),
    avgDailyL: _numOrNull(j['avg_daily_l']),
    recentAlerts: [
      for (final a in j['recent_alerts'] as List)
        Alert.fromJson(a as Map<String, dynamic>),
    ],
  );

  final Room room;
  final double? monthL;
  final double? avgDailyL;
  final List<Alert> recentAlerts;
}

class Alert {
  const Alert({
    required this.id,
    required this.roomId,
    required this.roomName,
    required this.type,
    required this.rule,
    required this.status,
    required this.createdAt,
    required this.resolvedAt,
    required this.resolvedBy,
    required this.detail,
  });

  factory Alert.fromJson(Map<String, dynamic> j) => Alert(
    id: j['id'] as int,
    roomId: j['room_id'] as int,
    roomName: j['room_name'] as String,
    type: _enum(AlertType.values, j['type']),
    rule: _enum(AlertRule.values, j['rule']),
    status: _enum(AlertStatus.values, j['status']),
    createdAt: _time(j['created_at']),
    resolvedAt: _timeOrNull(j['resolved_at']),
    resolvedBy: j['resolved_by'] as String?,
    detail: (j['detail'] as Map<String, dynamic>?) ?? const {},
  );

  final int id;
  final int roomId;
  final String roomName;
  final AlertType type;
  final AlertRule rule;
  final AlertStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  /// `APP` atau `MANUAL_BUTTON`.
  final String? resolvedBy;

  /// Isi bebas dari backend, mis. `flow_lpm`, `duration_min`, `ratio`.
  final Map<String, dynamic> detail;
}

/// `GET /v1/alerts`.
class AlertPage {
  const AlertPage({required this.items, required this.nextBefore});

  factory AlertPage.fromJson(Map<String, dynamic> j) => AlertPage(
    items: [
      for (final a in j['items'] as List)
        Alert.fromJson(a as Map<String, dynamic>),
    ],
    nextBefore: j['next_before'] as int?,
  );

  final List<Alert> items;
  final int? nextBefore;
}

class UsagePoint {
  const UsagePoint({required this.label, required this.volumeL});

  factory UsagePoint.fromJson(Map<String, dynamic> j) =>
      UsagePoint(label: j['label'] as String, volumeL: _num(j['volume_l']));

  /// `2026-11-07` (harian) atau `2026-11` (bulanan).
  final String label;
  final double volumeL;
}

class RoomUsage {
  const RoomUsage({
    required this.roomId,
    required this.name,
    required this.volumeL,
  });

  factory RoomUsage.fromJson(Map<String, dynamic> j) => RoomUsage(
    roomId: j['room_id'] as int,
    name: j['name'] as String,
    volumeL: _num(j['volume_l']),
  );

  final int roomId;
  final String name;
  final double volumeL;
}

/// `GET /v1/usage`.
class Usage {
  const Usage({
    required this.period,
    required this.series,
    required this.totalL,
    required this.averageL,
    required this.byRoom,
  });

  factory Usage.fromJson(Map<String, dynamic> j) => Usage(
    period: _enum(UsagePeriod.values, j['period']),
    series: [
      for (final p in j['series'] as List)
        UsagePoint.fromJson(p as Map<String, dynamic>),
    ],
    totalL: _num(j['total_l']),
    averageL: _num(j['average_l']),
    byRoom: [
      for (final r in (j['by_room'] as List?) ?? const [])
        RoomUsage.fromJson(r as Map<String, dynamic>),
    ],
  );

  final UsagePeriod period;
  final List<UsagePoint> series;
  final double totalL;
  final double averageL;
  final List<RoomUsage> byRoom;
}

/// `GET /v1/commands/{id}` dan item `GET /v1/rooms/{id}/commands`.
class ValveCommand {
  const ValveCommand({
    required this.id,
    required this.roomId,
    required this.action,
    required this.source,
    required this.status,
    required this.createdAt,
    required this.ackedAt,
  });

  factory ValveCommand.fromJson(Map<String, dynamic> j) => ValveCommand(
    id: j['id'] as int,
    roomId: j['room_id'] as int,
    action: _enum(CommandAction.values, j['action']),
    source: _enum(CommandSourceType.values, j['source']),
    status: _enum(CommandStatus.values, j['status']),
    createdAt: _time(j['created_at']),
    ackedAt: _timeOrNull(j['acked_at']),
  );

  final int id;
  final int roomId;
  final CommandAction action;
  final CommandSourceType source;
  final CommandStatus status;
  final DateTime createdAt;
  final DateTime? ackedAt;
}

// Dipakai repository untuk membaca daftar perintah dengan aman.
List<ValveCommand> commandsFromJson(Object? raw) {
  final list = raw is Map ? raw['items'] ?? raw['commands'] : raw;
  return [
    for (final c in list as List)
      ValveCommand.fromJson(c as Map<String, dynamic>),
  ];
}

// Ekspor helper enum untuk tes.
T parseEnum<T extends Enum>(List<T> values, Object? raw) => _enum(values, raw);
T? parseEnumOrNull<T extends Enum>(List<T> values, Object? raw) =>
    _enumOrNull(values, raw);

/// Ambang aturan kebocoran satu kamar: durasi dalam detik, jam sepi WIB
/// `HH:MM` (`GET/PUT /v1/rooms/{id}/rules`).
class RoomRules {
  const RoomRules({
    required this.roomId,
    required this.continuousSec,
    required this.stableSec,
    required this.quietSec,
    required this.quietStart,
    required this.quietEnd,
  });

  factory RoomRules.fromJson(Map<String, dynamic> j) => RoomRules(
    roomId: j['room_id'] as int,
    continuousSec: j['continuous_sec'] as int,
    stableSec: j['stable_sec'] as int,
    quietSec: j['quiet_sec'] as int,
    quietStart: j['quiet_start'] as String,
    quietEnd: j['quiet_end'] as String,
  );

  /// Batas nilai sesuai CONTRACT.md 2.10.
  static const minSec = 1;
  static const maxSec = 86400;

  final int roomId;
  final int continuousSec;
  final int stableSec;
  final int quietSec;
  final String quietStart;
  final String quietEnd;

  RoomRules copyWith({
    int? continuousSec,
    int? stableSec,
    int? quietSec,
    String? quietStart,
    String? quietEnd,
  }) => RoomRules(
    roomId: roomId,
    continuousSec: continuousSec ?? this.continuousSec,
    stableSec: stableSec ?? this.stableSec,
    quietSec: quietSec ?? this.quietSec,
    quietStart: quietStart ?? this.quietStart,
    quietEnd: quietEnd ?? this.quietEnd,
  );

  Map<String, dynamic> toJson() => {
    'continuous_sec': continuousSec,
    'stable_sec': stableSec,
    'quiet_sec': quietSec,
    'quiet_start': quietStart,
    'quiet_end': quietEnd,
  };
}

/// Skenario simulator Kamar 2 (`POST /v1/rooms/{id}/demo-scenario`).
enum DemoScenarioKind {
  normal('NORMAL'),
  leakContinuous('LEAK_CONTINUOUS'),
  leakStable('LEAK_STABLE'),
  leakQuietHours('LEAK_QUIET_HOURS'),
  offline('OFFLINE'),
  noAck('NO_ACK');

  const DemoScenarioKind(this.wire);

  final String wire;
}
