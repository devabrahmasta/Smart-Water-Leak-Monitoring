import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:smart_water/components/components.dart';
import 'package:smart_water/core/router/app_router.dart';
import 'package:smart_water/core/theme/app_icons.dart';
import 'package:smart_water/data/mock/mock_smart_water_repository.dart';
import 'package:smart_water/data/models/models.dart';

import '../helpers.dart';

Finder _navTab(String label) =>
    find.descendant(of: find.byType(BottomNav), matching: find.text(label));

Finder _switchOf(String room) => find.descendant(
  of: find.ancestor(of: find.text(room), matching: find.byType(RoomCard)),
  matching: find.byType(ValveSwitch),
);

/// Biarkan polling ACK berjalan sampai selesai.
Future<void> _settleCommand(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('tutup valve: konfirmasi → Pending → sukses (US-07)', (
    tester,
  ) async {
    final repo = await pumpApp(tester);
    await tester.tap(_navTab('Kamar'));
    await tester.pumpAndSettle();

    // Batal tidak mengirim apa pun.
    await tester.tap(_switchOf('Kamar 1'));
    await tester.pumpAndSettle();
    expect(find.text('Matikan air Kamar 1?'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(await repo.getRoomCommands(1), hasLength(2));

    await tester.tap(_switchOf('Kamar 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Matikan air'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 5));
    expect(find.text('Menunggu alat'), findsOneWidget);
    expect(
      tester.widget<ValveSwitch>(_switchOf('Kamar 1')).state,
      ValveSwitchState.pending,
    );

    await _settleCommand(tester);
    expect(find.text('Air Kamar 1 dimatikan'), findsOneWidget);
    await tester.pumpAndSettle();
    final cmds = await repo.getRoomCommands(1);
    expect(cmds.first.action, CommandAction.close);
    expect(cmds.first.source, CommandSourceType.app);
    expect(cmds.first.status, CommandStatus.success);
    expect(
      tester.widget<ValveSwitch>(_switchOf('Kamar 1')).state,
      ValveSwitchState.off,
    );

    await tester.pump(const Duration(seconds: 4)); // toast hilang
  });

  testWidgets('tanpa ACK: FAILED, saklar kembali, Toast error (US-07)', (
    tester,
  ) async {
    await pumpApp(tester, scenario: MockScenario.noAck);
    await tester.tap(_navTab('Kamar'));
    await tester.pumpAndSettle();

    await tester.tap(_switchOf('Kamar 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Matikan air'));
    await _settleCommand(tester);

    expect(find.text('Alat tidak merespons. Coba lagi'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(
      tester.widget<ValveSwitch>(_switchOf('Kamar 1')).state,
      ValveSwitchState.on,
    );
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets(
    'buka valve dari sheet alert me-RESOLVE kebocoran (US-08, US-11)',
    (tester) async {
      final repo = await pumpApp(tester);
      await tester.tap(_navTab('Notifikasi'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kebocoran di Kamar 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nyalakan air'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Nyalakan hanya kalau keran dan pipa sudah dicek'),
        findsOneWidget,
      );
      await tester.tap(find.text('Nyalakan air').last);
      await _settleCommand(tester);

      expect(find.text('Air Kamar 2 menyala'), findsOneWidget);
      final leak = (await repo.getAlerts()).items.firstWhere((a) => a.id == 31);
      expect(leak.status, AlertStatus.resolved);
      await tester.pump(const Duration(seconds: 4));
    },
  );

  testWidgets('kamar offline: saklar tidak bisa disentuh (US-09)', (
    tester,
  ) async {
    await pumpApp(tester, scenario: MockScenario.offline);
    await tester.tap(_switchOf('Kamar 2'));
    await tester.pumpAndSettle();
    expect(find.byType(ConfirmSheet), findsNothing);
  });

  testWidgets('izin notifikasi ditolak: baris pengingat bisa ditutup (US-20)', (
    tester,
  ) async {
    await pumpApp(tester, notificationsOn: false);
    expect(
      find.text('Notifikasi mati. Aktifkan di Pengaturan'),
      findsOneWidget,
    );
    await tester.tap(find.byIcon(AppIcons.close));
    await tester.pumpAndSettle();
    expect(find.text('Notifikasi mati. Aktifkan di Pengaturan'), findsNothing);
  });

  testWidgets('push dibuka: /notifikasi?alert=31 menampilkan detail', (
    tester,
  ) async {
    await pumpApp(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(BottomNav)),
    );
    container.read(routerProvider).go('${AppRoutes.alerts}?alert=31');
    await tester.pumpAndSettle();
    expect(find.text('Lihat kamar'), findsOneWidget);
    expect(find.text('Aliran stabil 6 menit'), findsOneWidget);
  });
}
