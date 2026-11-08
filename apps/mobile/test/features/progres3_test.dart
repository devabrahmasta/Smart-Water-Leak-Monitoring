import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:smart_water/components/components.dart';
import 'package:smart_water/core/config/env.dart';
import 'package:smart_water/core/presentation/labels.dart';
import 'package:smart_water/core/push/push_service.dart';
import 'package:smart_water/core/router/app_router.dart';
import 'package:smart_water/core/theme/app_colors.dart';
import 'package:smart_water/data/mock/mock_smart_water_repository.dart';
import 'package:smart_water/data/models/models.dart';
import 'package:smart_water/features/home/home_page.dart';
import 'package:smart_water/features/room_detail/room_rules_sheet.dart';

import '../helpers.dart';

/// Revisi Progres 3: kebocoran terasa genting, kalimat awam, penjelasan
/// bocor, rata-rata mingguan, mode demo. Kontrak tidak berubah.

Room _room(RoomStatus status) => Room(
  id: 2,
  name: 'Kamar 2',
  status: status,
  valve: status == RoomStatus.normal ? ValveState.open : ValveState.closed,
  todayL: status == RoomStatus.offline ? null : 142,
  flowLpm: status == RoomStatus.offline ? null : 0,
  isHighest: false,
  lastSeenAt: DateTime.utc(2026, 11, 7, 18, 52),
);

Alert _leak(AlertRule rule, Map<String, dynamic> detail) => Alert.fromJson({
  'id': 31,
  'room_id': 2,
  'room_name': 'Kamar 2',
  'type': 'LEAK',
  'rule': rule.name == 'quietHours' ? 'QUIET_HOURS' : rule.name.toUpperCase(),
  'status': 'OPEN',
  'created_at': '2026-11-07T19:14:00Z',
  'resolved_at': null,
  'detail': detail,
});

Color? _cardColor(WidgetTester tester, Finder within) {
  final box = tester.widget<Container>(
    find.descendant(of: within, matching: find.byType(Container)).first,
  );
  return (box.decoration as BoxDecoration?)?.color;
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  test('kalimat awam Room Card per status', () {
    expect(roomSummary(_room(RoomStatus.leak)), contains('Belum ditangani'));
    expect(
      roomSummary(_room(RoomStatus.normal)),
      'Tidak ada air yang mengalir. Hari ini terpakai 142 L.',
    );
    expect(roomSummary(_room(RoomStatus.offline)), contains('Cek listrik'));
  });

  test('penjelasan bocor mengikuti aturan kontrak 2.9', () {
    final continuous = leakExplanation(
      _leak(AlertRule.continuous, {'flow_lpm': 3.2, 'duration_min': 45}),
    );
    expect(continuous.why, contains('45 menit'));
    expect(continuous.why, contains('3,2 L/menit'));
    expect(continuous.steps, isNotEmpty);
    expect(
      leakExplanation(_leak(AlertRule.quietHours, {})).why,
      contains('01.00 sampai 04.00'),
    );
  });

  testWidgets('ada kebocoran: Summary Card merah, Room Card danger-soft', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(_cardColor(tester, find.byType(SummaryCard)), AppColors.danger);
    expect(
      _cardColor(tester, find.byType(RoomCard).first),
      AppColors.dangerSoft,
    );
  });

  testWidgets('semua normal: Summary Card kembali biru', (tester) async {
    await pumpApp(tester, scenario: MockScenario.allNormal);
    expect(_cardColor(tester, find.byType(SummaryCard)), AppColors.primary);
  });

  testWidgets('Detail Kamar bocor: penjelasan + rata rata mingguan', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byType(RoomCard).first);
    await tester.pumpAndSettle();
    expect(find.text('Kenapa terdeteksi bocor'), findsOneWidget);
    expect(find.text('Yang sebaiknya dilakukan'), findsOneWidget);
    expect(find.text('Rata rata mingguan'), findsOneWidget);
  });

  test('notifikasi diketuk: ke Detail Kamar, tanpa room_id ke sheet alert', () {
    expect(
      pushRoute({'type': 'LEAK', 'alert_id': '31', 'room_id': '2'}),
      AppRoutes.homeRoom(2),
    );
    expect(pushRoute({'alert_id': '31'}), '${AppRoutes.alerts}?alert=31');
  });

  testWidgets('rute notifikasi menampilkan panduan kebocoran Kamar 2', (
    tester,
  ) async {
    await pumpApp(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomePage)),
    );
    container
        .read(routerProvider)
        .go(pushRoute({'alert_id': '31', 'room_id': '2'}));
    await tester.pumpAndSettle();
    expect(find.text('Kenapa terdeteksi bocor'), findsOneWidget);
  });

  test('aplikasi memakai backend asli kecuali USE_MOCK diisi', () {
    expect(Env.useMock, isFalse);
  });

  testWidgets('Mode demo hanya mengatur Kamar 2', (tester) async {
    final repo = await pumpApp(tester);
    await tester.tap(find.bySemanticsLabel('Mode demo'));
    await tester.pumpAndSettle();
    expect(find.text('Data asli dari alat'), findsNothing);
    expect(find.text('Data contoh bawaan'), findsNothing);
    await tester.tap(find.text('Bocor: aliran stabil'));
    await tester.pumpAndSettle();
    expect(repo.lastDemoScenario, DemoScenarioKind.leakStable);
    await tester.pump(const Duration(seconds: 4));
  });

  Future<void> openRules(WidgetTester tester, String row) async {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomePage)),
    );
    container.read(routerProvider).go(AppRoutes.homeRoom(1));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Jam sepi'), 200);
    // Keluar dari bawah nav melayang.
    await tester.drag(find.byType(ListView).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text(row));
    await tester.pumpAndSettle();
  }

  testWidgets('satu aturan diubah sendiri, per kamar, sampai 5 detik', (
    tester,
  ) async {
    final repo = await pumpApp(tester);
    await openRules(tester, 'Aliran stabil');
    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.text('Jam'), findsOneWidget);
    expect(find.text('Menit'), findsOneWidget);
    expect(find.text('Detik'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), '00');
    await tester.enterText(find.byType(TextField).at(2), '05');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    final room1 = await repo.getRoomRules(1);
    expect(room1.stableSec, 5);
    expect(room1.continuousSec, 2700);
    expect((await repo.getRoomRules(2)).stableSec, 300);
    expect(find.text('5 detik'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('jam sepi diatur mulai dan selesai', (tester) async {
    final repo = await pumpApp(tester);
    await openRules(tester, 'Jam sepi');
    expect(find.byType(TextField), findsNWidgets(4));
    await tester.enterText(find.byType(TextField).at(0), '22');
    await tester.enterText(find.byType(TextField).at(1), '30');
    await tester.enterText(find.byType(TextField).at(2), '05');
    await tester.enterText(find.byType(TextField).at(3), '00');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    final rules = await repo.getRoomRules(1);
    expect(rules.quietStart, '22:30');
    expect(rules.quietEnd, '05:00');
    expect(rules.quietSec, 300);
    expect(find.text('22.30 sampai 05.00'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  test('isian durasi mengikuti batas kontrak', () {
    expect(parseDurationFields('00', '45', '00'), 2700);
    expect(parseDurationFields('', '', '5'), 5);
    expect(parseDurationFields('24', '00', '00'), 86400);
    expect(parseDurationFields('00', '00', '01'), 1);
    expect(parseDurationFields('00', '00', '00'), isNull);
    expect(parseDurationFields('24', '00', '01'), isNull);
    expect(parseDurationFields('00', '60', '00'), isNull);
  });

  test('isian jam mengikuti format HH:MM', () {
    expect(parseClockFields('1', '0'), '01:00');
    expect(parseClockFields('23', '59'), '23:59');
    expect(parseClockFields('24', '00'), isNull);
    expect(parseClockFields('', '00'), isNull);
  });

  test('durasi ditulis dalam bahasa sehari-hari', () {
    expect(formatDuration(5), '5 detik');
    expect(formatDuration(90), '1 menit 30 detik');
    expect(formatDuration(2700), '45 menit');
    expect(formatDuration(5400), '1 jam 30 menit');
  });
}
