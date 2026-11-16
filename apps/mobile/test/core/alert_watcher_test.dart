import 'package:flutter_test/flutter_test.dart';
import 'package:smart_water/core/push/push_service.dart';
import 'package:smart_water/data/models/models.dart';
import 'package:smart_water/data/repository/smart_water_repository.dart';

/// Repository palsu: hanya daftar alert OPEN yang bisa diganti di tes.
class _FakeRepo implements SmartWaterRepository {
  List<Alert> open = [];
  AlertStatus? lastStatus;

  @override
  Future<AlertPage> getAlerts({
    AlertStatus? status,
    int? limit,
    int? before,
  }) async {
    lastStatus = status;
    return AlertPage(items: open, nextBefore: null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Alert _alert(
  int id,
  int roomId, {
  AlertType type = AlertType.leak,
  AlertRule rule = AlertRule.stable,
  Map<String, dynamic> detail = const {},
}) => Alert(
  id: id,
  roomId: roomId,
  roomName: 'Kamar $roomId',
  type: type,
  rule: rule,
  status: AlertStatus.open,
  createdAt: DateTime.utc(2026, 11, 16),
  resolvedAt: null,
  resolvedBy: null,
  detail: detail,
);

void main() {
  late _FakeRepo repo;
  late List<Map<String, String>> shown;
  late AlertWatcher watcher;

  setUp(() {
    repo = _FakeRepo();
    shown = [];
    watcher = AlertWatcher(() => repo, show: (data) async => shown.add(data));
  });

  test('alert yang sudah ada saat mulai tidak dinotifikasi ulang', () async {
    repo.open = [_alert(1, 1)];
    await watcher.check();
    expect(shown, isEmpty);
    expect(repo.lastStatus, AlertStatus.open);
  });

  test('kebocoran baru di semua kamar dinotifikasi sekali', () async {
    await watcher.check();
    repo.open = [
      _alert(10, 1, rule: AlertRule.continuous), // alat asli
      _alert(11, 2), // simulator normal
      _alert(12, 3, rule: AlertRule.quietHours), // simulator Mode demo
    ];
    await watcher.check();
    await watcher.check();

    expect(shown.map((d) => d['room_id']), ['1', '2', '3']);
    expect(shown.first, {
      'type': 'LEAK',
      'alert_id': '10',
      'room_id': '1',
      'room_name': 'Kamar 1',
      'title': 'Kebocoran terdeteksi',
      'body': 'Kamar 1: aliran terus menerus. Valve sudah ditutup.',
    });
    expect(
      shown.last['body'],
      'Kamar 3: aliran di jam sepi terdeteksi. Valve sudah ditutup.',
    );
  });

  test('satu kebocoran yang tercatat dua baris hanya dinotifikasi sekali', () async {
    await watcher.check();
    repo.open = [
      _alert(30, 1, detail: {'msg_id': 2308, 'flow_lpm': 6.4}),
      _alert(31, 1, detail: {'msg_id': 2308, 'flow_lpm': 6.4}),
    ];
    await watcher.check();

    expect(shown, hasLength(1));
  });

  test('anomali ikut dinotifikasi, aktivitas tombol tidak', () async {
    await watcher.check();
    repo.open = [
      _alert(
        20,
        1,
        type: AlertType.anomaly,
        rule: AlertRule.dailyRatio,
        detail: {'ratio': 1.6},
      ),
      _alert(21, 1, type: AlertType.activity, rule: AlertRule.manualButton),
    ];
    await watcher.check();

    expect(shown, hasLength(1));
    expect(shown.single['title'], 'Anomali pemakaian terdeteksi');
    expect(shown.single['body'], 'Pemakaian Kamar 1 hari ini 1,6× rata-rata.');
  });
}
