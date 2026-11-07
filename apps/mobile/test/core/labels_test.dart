import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:smart_water/components/components.dart';
import 'package:smart_water/core/presentation/labels.dart';
import 'package:smart_water/data/models/models.dart';

Room _room(int id, RoomStatus status, {ValveState valve = ValveState.open}) =>
    Room(
      id: id,
      name: 'Kamar $id',
      status: status,
      valve: valve,
      todayL: status == RoomStatus.offline ? null : 10,
      flowLpm: status == RoomStatus.offline ? null : 1,
      isHighest: false,
      lastSeenAt: DateTime.utc(2026, 11, 7, 18, 52), // 01.52 WIB tgl 8
    );

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));
  final now = DateTime.utc(2026, 11, 7, 7, 30); // 14.30 WIB

  test('formatWhen: hari ini, kemarin, tanggal', () {
    expect(
      formatWhen(DateTime.utc(2026, 11, 6, 19, 14), now: now),
      'Hari ini 02.14',
    );
    expect(
      formatWhen(DateTime.utc(2026, 11, 6, 14, 0), now: now),
      'Kemarin 21.00',
    );
    expect(
      formatWhen(DateTime.utc(2026, 11, 2, 18, 40), now: now),
      '3 Nov 01.40',
    );
  });

  test(
    'Perlu dicek: urut Bocor, Offline, Tertutup; Normal tidak ikut (US-02)',
    () {
      final sorted = roomsNeedingAttention([
        _room(1, RoomStatus.closed, valve: ValveState.closed),
        _room(2, RoomStatus.normal),
        _room(3, RoomStatus.offline),
        _room(4, RoomStatus.leak, valve: ValveState.closed),
      ]);
      expect(sorted.map((r) => r.id), [4, 3, 1]);
    },
  );

  test('offline: saklar disabled dan "Terakhir terlihat" (US-09)', () {
    final r = _room(2, RoomStatus.offline);
    expect(valveSwitchState(r), ValveSwitchState.disabled);
    expect(valvePanelText(r).subtitle, 'Terakhir terlihat 01.52');
  });

  test('kamar belum pernah terhubung (US-18)', () {
    final r = Room(
      id: 3,
      name: 'Kamar 3',
      status: RoomStatus.offline,
      valve: ValveState.open,
      todayL: null,
      flowLpm: null,
      isHighest: false,
      lastSeenAt: null,
    );
    expect(valvePanelText(r).subtitle, 'Belum pernah terhubung');
  });

  test('judul dan subjudul alert', () {
    final leak = Alert(
      id: 1,
      roomId: 2,
      roomName: 'Kamar 2',
      type: AlertType.leak,
      rule: AlertRule.stable,
      status: AlertStatus.open,
      createdAt: DateTime.utc(2026, 11, 6, 19, 14),
      resolvedAt: null,
      resolvedBy: null,
      detail: const {'duration_min': 6},
    );
    expect(alertTitle(leak), 'Kebocoran di Kamar 2');
    expect(
      alertSubtitle(leak, now: now),
      'Aliran stabil 6 menit · Hari ini 02.14',
    );

    final anomaly = Alert(
      id: 2,
      roomId: 1,
      roomName: 'Kamar 1',
      type: AlertType.anomaly,
      rule: AlertRule.dailyRatio,
      status: AlertStatus.open,
      createdAt: DateTime.utc(2026, 11, 6, 14, 0),
      resolvedAt: null,
      resolvedBy: null,
      detail: const {'ratio': 1.7},
    );
    expect(
      alertSubtitle(anomaly, now: now),
      'Kamar 1 · 1,7× rata rata · Kemarin 21.00',
    );
  });

  test('label grafik', () {
    final daily = Usage(
      period: UsagePeriod.daily,
      series: const [
        UsagePoint(label: '2026-11-01', volumeL: 1),
        UsagePoint(label: '2026-11-06', volumeL: 2),
      ],
      totalL: 3,
      averageL: 1.5,
      byRoom: const [],
    );
    expect(usageRangeLabel(daily), '1 sampai 6 Nov');
    expect(chartPoints(daily).map((p) => p.label), ['1', '6']);

    final monthly = Usage(
      period: UsagePeriod.monthly,
      series: const [
        UsagePoint(label: '2026-06', volumeL: 1),
        UsagePoint(label: '2026-11', volumeL: 2),
      ],
      totalL: 3,
      averageL: 1.5,
      byRoom: const [],
    );
    expect(usageRangeLabel(monthly), 'Jun sampai Nov');
  });
}
