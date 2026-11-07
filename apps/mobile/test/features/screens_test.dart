import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:smart_water/components/components.dart';
import 'package:smart_water/data/mock/mock_smart_water_repository.dart';

import '../helpers.dart';

Finder _navTab(String label) =>
    find.descendant(of: find.byType(BottomNav), matching: find.text(label));

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('Beranda: ringkasan, banner bocor, Perlu dicek (US-01..03)', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.byType(SummaryCard), findsOneWidget);
    expect(find.text('Kebocoran di Kamar 2'), findsOneWidget);
    expect(find.textContaining('+1 lainnya'), findsOneWidget);
    expect(find.byType(StatusTally), findsOneWidget);
    // Hanya Kamar 2 (bocor) di Perlu dicek.
    expect(find.byType(RoomCard), findsOneWidget);
    expect(find.text('Bocor'), findsOneWidget);
    // Badge tab Notifikasi = 2 alert OPEN.
    expect(
      find.descendant(of: find.byType(BottomNav), matching: find.text('2')),
      findsOneWidget,
    );
  });

  testWidgets('Beranda semua normal: Empty State, tanpa banner', (
    tester,
  ) async {
    await pumpApp(tester, scenario: MockScenario.allNormal);
    expect(find.byType(AlertBanner), findsNothing);
    expect(find.text('Semua kamar normal'), findsOneWidget);
  });

  testWidgets('tanpa kamar: "Belum ada kamar terhubung" (US-18)', (
    tester,
  ) async {
    await pumpApp(tester, scenario: MockScenario.empty);
    expect(find.text('Belum ada kamar terhubung'), findsOneWidget);
  });

  testWidgets('Lihat grafik → Detail Grafik, ganti ke Bulanan (US-04)', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Lihat grafik'));
    await tester.pumpAndSettle();

    expect(find.text('Pemakaian harian'), findsOneWidget);
    expect(find.byType(MetricTile), findsNWidgets(2));
    expect(find.byType(RoomCompare), findsOneWidget);

    await tester.tap(find.text('Bulanan'));
    await tester.pumpAndSettle();
    expect(find.text('Pemakaian bulanan'), findsOneWidget);
    expect(find.text('Total 6 bulan'), findsOneWidget);
  });

  testWidgets('Kamar: filter dan buka Detail Kamar (US-05, US-06)', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(_navTab('Kamar'));
    await tester.pumpAndSettle();
    expect(find.byType(RoomCard), findsNWidgets(2));
    expect(find.text('Tertinggi'), findsOneWidget);

    await tester.tap(find.text('Perlu dicek'));
    await tester.pumpAndSettle();
    expect(find.byType(RoomCard), findsOneWidget);

    await tester.tap(find.text('Offline'));
    await tester.pumpAndSettle();
    expect(find.text('Semua perangkat online'), findsOneWidget);

    await tester.tap(find.text('Semua'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kamar 1').first);
    await tester.pumpAndSettle();

    expect(find.byType(MetricTile), findsNWidgets(2));
    await tester.scrollUntilVisible(find.text('Riwayat perintah'), 300);
    expect(find.byType(CommandRow), findsWidgets);
    await tester.scrollUntilVisible(find.text('Alert terakhir'), 300);
    expect(find.byType(AlertItem), findsWidgets);
  });

  testWidgets('Notifikasi: filter Aktif/Selesai dan sheet detail (US-11)', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(_navTab('Notifikasi'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertItem), findsNWidgets(4));

    await tester.tap(find.text('Aktif').first);
    await tester.pumpAndSettle();
    expect(find.byType(AlertItem), findsNWidgets(2));
    // ACTIVITY hanya tampil di Semua.
    expect(find.textContaining('dibuka'), findsNothing);

    await tester.tap(find.text('Selesai').first);
    await tester.pumpAndSettle();
    expect(find.byType(AlertItem), findsOneWidget);

    await tester.tap(find.byType(AlertItem));
    await tester.pumpAndSettle();
    expect(find.text('Lihat kamar'), findsOneWidget);
    expect(find.text('Aliran jam sepi'), findsOneWidget);

    await tester.tap(find.text('Lihat kamar'));
    await tester.pumpAndSettle();
    expect(find.byType(RoomCard), findsOneWidget);
  });

  testWidgets('offline: Room Card "Tidak ada data" (US-09)', (tester) async {
    await pumpApp(tester, scenario: MockScenario.offline);
    expect(
      find.descendant(
        of: find.byType(StatusChip),
        matching: find.text('Offline'),
      ),
      findsOneWidget,
    );
    expect(find.text('Tidak ada data'), findsNWidgets(2));
    expect(find.text('Kontrol tidak tersedia'), findsOneWidget);
  });

  testWidgets('tidak ada overflow di layar kecil 320 px', (tester) async {
    await pumpApp(tester);
    tester.view.physicalSize = const Size(320, 640) * 2;
    tester.view.devicePixelRatio = 2;
    await tester.pumpAndSettle();
    await tester.tap(_navTab('Kamar'));
    await tester.pumpAndSettle();
    await tester.tap(_navTab('Notifikasi'));
    await tester.pumpAndSettle();
    // Overflow akan menggagalkan tes otomatis.
    expect(find.byType(Scaffold), findsWidgets);
  });
}
