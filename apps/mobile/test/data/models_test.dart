import 'package:flutter_test/flutter_test.dart';
import 'package:smart_water/data/models/models.dart';

/// JSON di bawah disalin dari contoh CONTRACT.md bagian 3. Kalau tes ini
/// gagal, model tidak lagi cocok dengan kontrak.
void main() {
  test('Summary', () {
    final s = Summary.fromJson({
      'today_l': 312.5,
      'month_l': 4812.0,
      'last_7_days_end': '2026-11-07',
      'last_7_days_l': [210.4, 198.2, 240.0, 305.7, 188.9, 276.3, 312.5],
      'tally': {'normal': 1, 'closed': 0, 'offline': 1},
      'open_alert_count': 1,
      'latest_open_alert': {
        'id': 31,
        'room_id': 1,
        'room_name': 'Kamar 1',
        'type': 'LEAK',
        'created_at': '2026-11-07T07:22:00Z',
      },
    });
    expect(s.monthL, 4812);
    expect(s.last7DaysL, hasLength(7));
    expect(s.tallyOffline, 1);
    expect(s.latestOpenAlert!.type, AlertType.leak);
    expect(s.latestOpenAlert!.createdAt.isUtc, isTrue);
  });

  test('Room: kamar offline memakai null', () {
    final rooms = [
      {
        'id': 1,
        'name': 'Kamar 1',
        'status': 'NORMAL',
        'valve': 'OPEN',
        'today_l': 182.4,
        'flow_lpm': 6.4,
        'is_highest': true,
        'last_seen_at': '2026-11-07T07:21:30Z',
      },
      {
        'id': 2,
        'name': 'Kamar 2',
        'status': 'OFFLINE',
        'valve': 'OPEN',
        'today_l': null,
        'flow_lpm': null,
        'is_highest': false,
        'last_seen_at': '2026-11-07T06:50:02Z',
      },
    ].map(Room.fromJson).toList();

    expect(rooms[0].status, RoomStatus.normal);
    expect(rooms[0].flowLpm, 6.4);
    expect(rooms[1].status, RoomStatus.offline);
    expect(rooms[1].todayL, isNull);
  });

  test('Alert dengan rule QUIET_HOURS dan detail', () {
    final a = Alert.fromJson({
      'id': 31,
      'room_id': 1,
      'room_name': 'Kamar 1',
      'type': 'LEAK',
      'rule': 'QUIET_HOURS',
      'status': 'OPEN',
      'created_at': '2026-11-07T07:22:00Z',
      'resolved_at': null,
      'resolved_by': null,
      'detail': {'flow_lpm': 6.4, 'duration_min': 45},
    });
    expect(a.rule, AlertRule.quietHours);
    expect(a.detail['duration_min'], 45);
  });

  test('Usage', () {
    final u = Usage.fromJson({
      'period': 'daily',
      'series': [
        {'label': '2026-11-07', 'volume_l': 312.5},
      ],
      'total_l': 1731.9,
      'average_l': 247.4,
      'peak': {'label': '2026-11-04', 'volume_l': 305.7},
      'by_room': [
        {'room_id': 1, 'name': 'Kamar 1', 'volume_l': 1100.2},
      ],
    });
    expect(u.period, UsagePeriod.daily);
    expect(u.series.single.volumeL, 312.5);
    expect(u.byRoom.single.roomId, 1);
  });

  test('ValveCommand', () {
    final c = ValveCommand.fromJson({
      'id': 512,
      'room_id': 2,
      'action': 'OPEN',
      'source': 'MANUAL_BUTTON',
      'status': 'PENDING',
      'created_at': '2026-11-07T07:30:00Z',
      'acked_at': null,
    });
    expect(c.source, CommandSourceType.manualButton);
    expect(c.status, CommandStatus.pending);
  });

  test('enum ke format kontrak', () {
    expect(enumToContract(CommandAction.close), 'CLOSE');
    expect(enumToContract(AlertRule.quietHours), 'QUIET_HOURS');
    expect(enumToContract(CommandSourceType.manualButton), 'MANUAL_BUTTON');
  });
}
