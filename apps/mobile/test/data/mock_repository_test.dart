import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:smart_water/core/network/api_exception.dart';
import 'package:smart_water/data/mock/mock_smart_water_repository.dart';
import 'package:smart_water/data/models/models.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  MockSmartWaterRepository repo([MockScenario s = MockScenario.standard]) =>
      MockSmartWaterRepository(
        scenario: s,
        latency: Duration.zero,
        ackDelay: const Duration(milliseconds: 10),
        clock: () => DateTime.utc(2026, 11, 7, 7, 30), // 14.30 WIB
      );

  test('standar: Kamar 2 bocor, ringkasan konsisten', () async {
    final r = repo();
    final rooms = await r.getRooms();
    final summary = await r.getSummary();

    expect(rooms.map((e) => e.status), [RoomStatus.normal, RoomStatus.leak]);
    expect(summary.latestOpenAlert!.type, AlertType.leak);
    expect(summary.last7DaysL, hasLength(7));
    final sumToday = rooms.fold<double>(0, (s, e) => s + e.todayL!);
    expect(summary.todayL, closeTo(sumToday, 0.01));
  });

  test('grafik harian dari tanggal 1 sampai hari ini (WIB)', () async {
    final u = await repo().getUsage(UsagePeriod.daily);
    expect(u.series.first.label, '2026-11-01');
    expect(u.series.last.label, '2026-11-07');
    expect(u.byRoom, hasLength(2));
  });

  test('kosong: tanpa kamar (US-18)', () async {
    final r = repo(MockScenario.empty);
    expect(await r.getRooms(), isEmpty);
    expect((await r.getSummary()).todayL, 0);
  });

  test('offline: perintah valve ditolak DEVICE_OFFLINE (US-09)', () async {
    final r = repo(MockScenario.offline);
    await expectLater(
      r.sendValveCommand(2, CommandAction.close),
      throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'code',
          ApiErrorCode.deviceOffline,
        ),
      ),
    );
  });

  test(
    'buka valve: PENDING → SUCCESS dan alert LEAK jadi RESOLVED (US-08)',
    () async {
      final r = repo();
      final id = await r.sendValveCommand(2, CommandAction.open);
      expect((await r.getCommand(id)).status, CommandStatus.pending);

      await expectLater(
        r.sendValveCommand(2, CommandAction.open),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            ApiErrorCode.commandInProgress,
          ),
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect((await r.getCommand(id)).status, CommandStatus.success);
      final room = (await r.getRooms()).firstWhere((e) => e.id == 2);
      expect(room.valve, ValveState.open);
      expect(room.status, RoomStatus.normal);
      final leak = (await r.getAlerts()).items.firstWhere((a) => a.id == 31);
      expect(leak.status, AlertStatus.resolved);
      expect(leak.resolvedBy, 'APP');
    },
  );
}
