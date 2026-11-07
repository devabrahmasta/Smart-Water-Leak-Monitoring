import 'dart:async';
import 'dart:math' as math;

import '../../core/format/formatters.dart';
import '../../core/network/api_exception.dart';
import '../models/models.dart';
import '../repository/smart_water_repository.dart';

/// Skenario data mock, dipilih lewat `--dart-define=MOCK_SCENARIO=...`.
enum MockScenario {
  /// Kamar 1 normal, Kamar 2 bocor (sama dengan Figma Beranda).
  standard,

  /// Semua kamar normal (Figma "Beranda · semua normal").
  allNormal,

  /// Kamar 2 offline.
  offline,

  /// Belum ada kamar terhubung (US-18).
  empty,

  /// Perangkat tidak membalas ACK (uji timeout 15 dtk, US-07).
  noAck;

  static MockScenario parse(String raw) => switch (raw) {
    'all-normal' => allNormal,
    'offline' => offline,
    'empty' => empty,
    'no-ack' => noAck,
    _ => standard,
  };
}

class _MockRoom {
  _MockRoom(
    this.id,
    this.name, {
    required this.valve,
    required this.flow,
    this.online = true,
    this.baseDaily = 200,
  });

  final int id;
  final String name;
  String valve;
  double flow;
  bool online;
  final double baseDaily;
  DateTime? offlineSince;
}

/// Implementasi palsu yang membentuk JSON persis seperti contoh di
/// CONTRACT.md lalu mem-parse-nya dengan model yang sama dengan API asli.
/// Jadi bila parse di sini lolos, layar siap untuk backend sungguhan.
class MockSmartWaterRepository implements SmartWaterRepository {
  MockSmartWaterRepository({
    this.scenario = MockScenario.standard,
    DateTime Function()? clock,
    this.latency = const Duration(milliseconds: 250),
    this.ackDelay = const Duration(seconds: 2),
  }) : _clock = clock ?? DateTime.now {
    _seed();
  }

  final MockScenario scenario;
  final DateTime Function() _clock;
  final Duration latency;
  final Duration ackDelay;

  /// Batas tunggu ACK di backend (CONTRACT.md 2.7).
  static const ackTimeout = Duration(seconds: 15);

  final _rooms = <_MockRoom>[];
  final _alerts = <Map<String, dynamic>>[];
  final _commands = <Map<String, dynamic>>[];
  int _nextCommandId = 600;

  DateTime get _now => _clock().toUtc();

  String _iso(DateTime t) =>
      t.toUtc().toIso8601String().replaceFirst(RegExp(r'\.\d+Z$'), 'Z');

  /// Waktu UTC untuk jam WIB tertentu, [daysAgo] hari lalu.
  DateTime _wibAt(int daysAgo, int hour, int minute) {
    final wib = toWib(_now);
    final day = DateTime.utc(
      wib.year,
      wib.month,
      wib.day - daysAgo,
      hour,
      minute,
    );
    return day.subtract(wibOffset);
  }

  void _seed() {
    if (scenario == MockScenario.empty) return;

    final leak =
        scenario == MockScenario.standard || scenario == MockScenario.noAck;
    _rooms
      ..add(_MockRoom(1, 'Kamar 1', valve: 'OPEN', flow: 6.4, baseDaily: 150))
      ..add(
        _MockRoom(
          2,
          'Kamar 2',
          valve: leak ? 'CLOSED' : 'OPEN',
          flow: leak ? 0 : 1.2,
          online: scenario != MockScenario.offline,
          baseDaily: 110,
        ),
      );
    if (scenario == MockScenario.offline) {
      _rooms[1].offlineSince = _wibAt(0, 1, 52);
    }

    if (leak) {
      _alerts.add(
        _alert(
          id: 31,
          roomId: 2,
          type: 'LEAK',
          rule: 'STABLE',
          status: 'OPEN',
          at: _wibAt(0, 2, 14),
          detail: {'flow_lpm': 3.2, 'duration_min': 6},
        ),
      );
      _commands.add(_command(2, 'CLOSE', 'AUTO', 'SUCCESS', _wibAt(0, 2, 14)));
    }
    _alerts.addAll([
      _alert(
        id: 28,
        roomId: 1,
        type: 'ANOMALY',
        rule: 'DAILY_RATIO',
        status: scenario == MockScenario.standard ? 'OPEN' : 'RESOLVED',
        at: _wibAt(1, 21, 0),
        detail: {'ratio': 1.7},
      ),
      _alert(
        id: 25,
        roomId: 2,
        type: 'ACTIVITY',
        rule: 'MANUAL_BUTTON',
        status: 'INFO',
        at: _wibAt(2, 14, 20),
        detail: {'valve': 'OPEN'},
      ),
      _alert(
        id: 22,
        roomId: 1,
        type: 'LEAK',
        rule: 'QUIET_HOURS',
        status: 'RESOLVED',
        at: _wibAt(4, 1, 40),
        resolvedAt: _wibAt(4, 7, 5),
        resolvedBy: 'APP',
        detail: {'flow_lpm': 1.4, 'duration_min': 5},
      ),
    ]);
    _commands.addAll([
      _command(1, 'OPEN', 'APP', 'SUCCESS', _wibAt(4, 7, 5)),
      _command(1, 'CLOSE', 'AUTO', 'SUCCESS', _wibAt(4, 1, 40)),
      _command(2, 'OPEN', 'MANUAL_BUTTON', 'SUCCESS', _wibAt(2, 14, 20)),
    ]);
  }

  Map<String, dynamic> _alert({
    required int id,
    required int roomId,
    required String type,
    required String rule,
    required String status,
    required DateTime at,
    DateTime? resolvedAt,
    String? resolvedBy,
    Map<String, dynamic> detail = const {},
  }) => {
    'id': id,
    'room_id': roomId,
    'room_name': 'Kamar $roomId',
    'type': type,
    'rule': rule,
    'status': status,
    'created_at': _iso(at),
    'resolved_at': resolvedAt == null ? null : _iso(resolvedAt),
    'resolved_by': resolvedBy,
    'detail': detail,
  };

  Map<String, dynamic> _command(
    int roomId,
    String action,
    String source,
    String status,
    DateTime at,
  ) => {
    'id': _nextCommandId++,
    'room_id': roomId,
    'action': action,
    'source': source,
    'status': status,
    'created_at': _iso(at),
    'acked_at': status == 'PENDING'
        ? null
        : _iso(at.add(const Duration(seconds: 2))),
  };

  Future<T> _delay<T>(T Function() body) async {
    await Future<void>.delayed(latency);
    return body();
  }

  _MockRoom _room(int id) => _rooms.firstWhere(
    (r) => r.id == id,
    orElse: () => throw const ApiException(
      ApiErrorCode.notFound,
      'Kamar tidak ditemukan',
      statusCode: 404,
    ),
  );

  // ---- Pemakaian sintetis yang stabil per tanggal ----

  double _dailyVolume(_MockRoom room, DateTime wibDate) {
    final seed =
        wibDate.year * 1000 + wibDate.month * 40 + wibDate.day + room.id * 7;
    final wave = (math.sin(seed * 1.7) + 1) / 2; // 0..1
    var v = room.baseDaily * (0.7 + wave * 0.7);
    if (room.id == 2 && wibDate.day % 9 == 4) v *= 1.9; // satu hari boros
    return (v * 10).roundToDouble() / 10;
  }

  double _todayVolume(_MockRoom room) {
    final wib = toWib(_now);
    // Pemakaian hari ini naik sepanjang hari.
    final fraction = (wib.hour * 60 + wib.minute) / (24 * 60);
    final today = DateTime.utc(wib.year, wib.month, wib.day);
    return ((_dailyVolume(room, today) * math.max(0.15, fraction)) * 10)
            .roundToDouble() /
        10;
  }

  double _volumeOn(_MockRoom room, DateTime wibDate) {
    final wib = toWib(_now);
    final isToday =
        wibDate.year == wib.year &&
        wibDate.month == wib.month &&
        wibDate.day == wib.day;
    return isToday ? _todayVolume(room) : _dailyVolume(room, wibDate);
  }

  double _monthVolume(_MockRoom room, int year, int month) {
    final wib = toWib(_now);
    final current = year == wib.year && month == wib.month;
    final days = current ? wib.day : DateTime.utc(year, month + 1, 0).day;
    var sum = 0.0;
    for (var d = 1; d <= days; d++) {
      sum += _volumeOn(room, DateTime.utc(year, month, d));
    }
    return (sum * 10).roundToDouble() / 10;
  }

  // ---- Status kamar seperti aturan backend ----

  bool _hasOpenLeak(int roomId) => _alerts.any(
    (a) =>
        a['room_id'] == roomId && a['type'] == 'LEAK' && a['status'] == 'OPEN',
  );

  String _status(_MockRoom r) {
    if (!r.online) return 'OFFLINE';
    if (_hasOpenLeak(r.id)) return 'LEAK';
    if (r.valve == 'CLOSED') return 'CLOSED';
    return 'NORMAL';
  }

  Map<String, dynamic> _roomJson(_MockRoom r, {required bool highest}) {
    final online = r.online;
    return {
      'id': r.id,
      'name': r.name,
      'status': _status(r),
      'valve': r.valve,
      'today_l': online ? _todayVolume(r) : null,
      'flow_lpm': online ? (r.valve == 'OPEN' ? r.flow : 0.0) : null,
      'is_highest': highest,
      'last_seen_at': _iso(
        online ? _now.subtract(const Duration(seconds: 6)) : r.offlineSince!,
      ),
    };
  }

  List<Map<String, dynamic>> _roomsJson() {
    final online = _rooms.where((r) => r.online).toList();
    final top = online.isEmpty
        ? null
        : online.reduce((a, b) => _todayVolume(a) >= _todayVolume(b) ? a : b);
    return [
      for (final r in _rooms)
        _roomJson(r, highest: r == top && _rooms.length > 1),
    ];
  }

  List<Map<String, dynamic>> _sortedAlerts() => [..._alerts]
    ..sort(
      (a, b) =>
          (b['created_at'] as String).compareTo(a['created_at'] as String),
    );

  // ---- SmartWaterRepository ----

  @override
  Future<Summary> getSummary() => _delay(() {
    final wib = toWib(_now);
    final rooms = _roomsJson();
    final open = _sortedAlerts().where((a) => a['status'] == 'OPEN').toList();
    final last7 = [
      for (var i = 6; i >= 0; i--)
        _rooms.fold<double>(
          0,
          (s, r) =>
              s + _volumeOn(r, DateTime.utc(wib.year, wib.month, wib.day - i)),
        ),
    ];
    final json = {
      'today_l': _rooms.fold<double>(0, (s, r) => s + _todayVolume(r)),
      'month_l': _rooms.fold<double>(
        0,
        (s, r) => s + _monthVolume(r, wib.year, wib.month),
      ),
      'last_7_days_end':
          '${wib.year}-${wib.month.toString().padLeft(2, '0')}-${wib.day.toString().padLeft(2, '0')}',
      'last_7_days_l': last7,
      'tally': {
        'normal': rooms.where((r) => r['status'] == 'NORMAL').length,
        'closed': rooms
            .where((r) => r['status'] == 'CLOSED' || r['status'] == 'LEAK')
            .length,
        'offline': rooms.where((r) => r['status'] == 'OFFLINE').length,
      },
      'open_alert_count': open.length,
      'latest_open_alert': open.isEmpty
          ? null
          : {
              for (final k in [
                'id',
                'room_id',
                'room_name',
                'type',
                'created_at',
              ])
                k: open.first[k],
            },
    };
    return Summary.fromJson(json);
  });

  @override
  Future<List<Room>> getRooms() =>
      _delay(() => [for (final r in _roomsJson()) Room.fromJson(r)]);

  @override
  Future<RoomDetail> getRoom(int id) => _delay(() {
    final room = _room(id);
    final wib = toWib(_now);
    final json = {
      'room': _roomsJson().firstWhere((r) => r['id'] == id),
      'month_l': _monthVolume(room, wib.year, wib.month),
      'avg_daily_l':
          (_monthVolume(room, wib.year, wib.month) / wib.day * 10)
              .roundToDouble() /
          10,
      'recent_alerts': _sortedAlerts()
          .where((a) => a['room_id'] == id)
          .take(3)
          .toList(),
    };
    return RoomDetail.fromJson(json);
  });

  @override
  Future<Usage> getUsage(UsagePeriod period, {int? roomId}) => _delay(() {
    final wib = toWib(_now);
    final rooms = roomId == null ? _rooms : [_room(roomId)];
    final series = <Map<String, dynamic>>[];
    final byRoom = <int, double>{for (final r in rooms) r.id: 0};

    if (period == UsagePeriod.daily) {
      for (var d = 1; d <= wib.day; d++) {
        final date = DateTime.utc(wib.year, wib.month, d);
        var total = 0.0;
        for (final r in rooms) {
          final v = _volumeOn(r, date);
          total += v;
          byRoom[r.id] = byRoom[r.id]! + v;
        }
        series.add({
          'label':
              '${wib.year}-${wib.month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}',
          'volume_l': (total * 10).roundToDouble() / 10,
        });
      }
    } else {
      for (var i = 5; i >= 0; i--) {
        final m = DateTime.utc(wib.year, wib.month - i);
        var total = 0.0;
        for (final r in rooms) {
          final v = _monthVolume(r, m.year, m.month);
          total += v;
          byRoom[r.id] = byRoom[r.id]! + v;
        }
        series.add({
          'label': '${m.year}-${m.month.toString().padLeft(2, '0')}',
          'volume_l': (total * 10).roundToDouble() / 10,
        });
      }
    }

    final total = series.fold<double>(
      0,
      (s, p) => s + (p['volume_l'] as double),
    );
    final values = series.map((p) => p['volume_l'] as double).toList();
    final peakIndex = values.isEmpty
        ? 0
        : values.indexOf(values.reduce(math.max));
    final json = {
      'period': period.name,
      'series': series,
      'total_l': (total * 10).roundToDouble() / 10,
      'average_l': series.isEmpty
          ? 0.0
          : (total / series.length * 10).roundToDouble() / 10,
      'peak': series.isEmpty ? null : series[peakIndex],
      'by_room': [
        for (final r in rooms)
          {
            'room_id': r.id,
            'name': r.name,
            'volume_l': (byRoom[r.id]! * 10).roundToDouble() / 10,
          },
      ],
    };
    return Usage.fromJson(json);
  });

  @override
  Future<AlertPage> getAlerts({AlertStatus? status, int? limit, int? before}) =>
      _delay(() {
        var items = _sortedAlerts();
        if (status != null) {
          final s = enumToContract(status);
          items = items.where((a) => a['status'] == s).toList();
        }
        if (before != null) {
          items = items.where((a) => (a['id'] as int) < before).toList();
        }
        if (limit != null && items.length > limit) {
          items = items.take(limit).toList();
        }
        return AlertPage.fromJson({'items': items, 'next_before': null});
      });

  @override
  Future<Alert> getAlert(int id) => _delay(() {
    final a = _alerts.where((a) => a['id'] == id);
    if (a.isEmpty) {
      throw const ApiException(
        ApiErrorCode.notFound,
        'Alert tidak ditemukan',
        statusCode: 404,
      );
    }
    return Alert.fromJson(a.first);
  });

  @override
  Future<List<ValveCommand>> getRoomCommands(int roomId, {int limit = 10}) =>
      _delay(() {
        _room(roomId);
        final items = _commands.where((c) => c['room_id'] == roomId).toList()
          ..sort(
            (a, b) => (b['created_at'] as String).compareTo(
              a['created_at'] as String,
            ),
          );
        return commandsFromJson(items.take(limit).toList());
      });

  @override
  Future<int> sendValveCommand(int roomId, CommandAction action) => _delay(() {
    final room = _room(roomId);
    if (!room.online) {
      throw ApiException(
        ApiErrorCode.deviceOffline,
        'Perangkat ${room.name} sedang offline',
        statusCode: 409,
      );
    }
    if (_commands.any(
      (c) => c['room_id'] == roomId && c['status'] == 'PENDING',
    )) {
      throw const ApiException(
        ApiErrorCode.commandInProgress,
        'Masih ada perintah yang menunggu',
        statusCode: 409,
      );
    }
    final cmd = _command(
      roomId,
      enumToContract(action),
      'APP',
      'PENDING',
      _now,
    );
    _commands.add(cmd);

    if (scenario == MockScenario.noAck) {
      Timer(ackTimeout, () => cmd['status'] = 'FAILED');
    } else {
      Timer(ackDelay, () => _ack(room, cmd, action));
    }
    return cmd['id'] as int;
  });

  void _ack(_MockRoom room, Map<String, dynamic> cmd, CommandAction action) {
    cmd['status'] = 'SUCCESS';
    cmd['acked_at'] = _iso(_now);
    room.valve = action == CommandAction.open ? 'OPEN' : 'CLOSED';
    if (action == CommandAction.open) {
      room.flow = 2.1;
      // US-08: OPEN sukses me-RESOLVE semua alert LEAK OPEN di kamar itu.
      for (final a in _alerts) {
        if (a['room_id'] == room.id &&
            a['type'] == 'LEAK' &&
            a['status'] == 'OPEN') {
          a['status'] = 'RESOLVED';
          a['resolved_at'] = _iso(_now);
          a['resolved_by'] = 'APP';
        }
      }
    }
  }

  @override
  Future<ValveCommand> getCommand(int id) => _delay(() {
    final c = _commands.where((c) => c['id'] == id);
    if (c.isEmpty) {
      throw const ApiException(
        ApiErrorCode.notFound,
        'Perintah tidak ditemukan',
        statusCode: 404,
      );
    }
    return ValveCommand.fromJson(c.first);
  });

  @override
  Future<void> registerPushToken(String token) => _delay(() {});
}
