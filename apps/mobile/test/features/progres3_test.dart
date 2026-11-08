import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:smart_water/components/components.dart';
import 'package:smart_water/core/presentation/labels.dart';
import 'package:smart_water/core/push/push_service.dart';
import 'package:smart_water/core/router/app_router.dart';
import 'package:smart_water/core/theme/app_colors.dart';
import 'package:smart_water/data/mock/mock_smart_water_repository.dart';
import 'package:smart_water/data/models/models.dart';
import 'package:smart_water/data/providers/providers.dart';
import 'package:smart_water/features/home/home_page.dart';

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
      contains('01.00 dan 04.00'),
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

  test('mode demo mengganti sumber data ke skenario mock', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(demoScenarioProvider.notifier).set(MockScenario.offline);
    final repo = container.read(repositoryProvider);
    expect(repo, isA<MockSmartWaterRepository>());
    expect((repo as MockSmartWaterRepository).scenario, MockScenario.offline);
  });
}
