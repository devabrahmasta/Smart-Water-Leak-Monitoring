import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:smart_water/components/components.dart';
import 'package:smart_water/core/theme/app_colors.dart';
import 'package:smart_water/core/theme/app_theme.dart';
import 'package:smart_water/features/gallery/component_gallery_page.dart';

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(20), child: child),
  ),
);

Color? _boxColor(WidgetTester tester, Finder finder) {
  final container = tester.widget<Container>(
    find.descendant(of: finder, matching: find.byType(Container)).first,
  );
  return (container.decoration as BoxDecoration?)?.color;
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('AppButton', () {
    testWidgets('memanggil onPressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(AppButton(label: 'Buka valve', onPressed: () => taps++)),
      );
      await tester.tap(find.text('Buka valve'));
      expect(taps, 1);
    });

    testWidgets('loading menampilkan spinner dan tidak bisa ditekan', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(AppButton(label: 'Buka', loading: true, onPressed: () => taps++)),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Buka'));
      expect(taps, 0);
    });
  });

  group('ValveSwitch', () {
    testWidgets('on → minta tutup (false)', (tester) async {
      bool? requested;
      await tester.pumpWidget(
        _host(
          ValveSwitch(
            state: ValveSwitchState.on,
            onChanged: (v) => requested = v,
          ),
        ),
      );
      await tester.tap(find.byType(ValveSwitch));
      expect(requested, isFalse);
    });

    testWidgets('pending dan disabled tidak bisa disentuh (US-07, US-09)', (
      tester,
    ) async {
      for (final state in [
        ValveSwitchState.pending,
        ValveSwitchState.disabled,
      ]) {
        var calls = 0;
        await tester.pumpWidget(
          _host(ValveSwitch(state: state, onChanged: (_) => calls++)),
        );
        await tester.tap(find.byType(ValveSwitch));
        expect(calls, 0, reason: '$state');
      }
    });
  });

  group('RoomCard', () {
    testWidgets('offline: "Tidak ada data" dan saklar disabled (US-09)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const RoomCard(
            name: 'Kamar 2',
            status: RoomCardStatus.offline,
            todayLiters: null,
            flowLpm: null,
            valveTitle: 'Kontrol tidak tersedia',
            valveSubtitle: 'Terakhir terlihat 01.52',
            switchState: ValveSwitchState.disabled,
          ),
        ),
      );
      expect(find.text('Tidak ada data'), findsNWidgets(2));
      expect(find.text('Offline'), findsOneWidget);
      expect(find.text('Kontrol tidak tersedia'), findsOneWidget);
    });

    testWidgets('valve tertutup = satu-satunya kartu gelap', (tester) async {
      await tester.pumpWidget(
        _host(
          const RoomCard(
            name: 'Kamar 2',
            status: RoomCardStatus.closed,
            todayLiters: 88,
            flowLpm: 0,
            valveTitle: 'Ditutup dari aplikasi',
            valveSubtitle: '14.20 hari ini',
            switchState: ValveSwitchState.off,
          ),
        ),
      );
      expect(_boxColor(tester, find.byType(RoomCard)), AppColors.ink);
      expect(find.text('Air dimatikan'), findsOneWidget);
    });

    testWidgets('format angka id_ID dan chip Tertinggi', (tester) async {
      await tester.pumpWidget(
        _host(
          const RoomCard(
            name: 'Kamar 1',
            status: RoomCardStatus.normal,
            todayLiters: 1182.4,
            flowLpm: 6.4,
            isHighest: true,
            valveTitle: 'Valve terbuka',
            valveSubtitle: 'Data 10 detik lalu',
            switchState: ValveSwitchState.on,
          ),
        ),
      );
      expect(find.textContaining('1.182,4'), findsOneWidget);
      expect(find.textContaining('6,4'), findsOneWidget);
      expect(find.text('Tertinggi'), findsOneWidget);
      expect(find.text('Normal'), findsOneWidget);
    });
  });

  group('UsageChartCard', () {
    testWidgets('label nilai di bar tertinggi, tap bar lain pindah label', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const UsageChartCard(
            title: 'Pemakaian harian',
            rangeLabel: '1 sampai 3 Nov',
            points: [
              ChartPoint(label: '1', liters: 100),
              ChartPoint(label: '2', liters: 1004),
              ChartPoint(label: '3', liters: 300),
            ],
          ),
        ),
      );
      expect(find.text('1.004 L'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('3: 300 L'));
      await tester.pump();
      expect(find.text('300 L'), findsOneWidget);
      expect(find.text('1.004 L'), findsNothing);
    });

    testWidgets('tanpa data menampilkan teks, bukan sumbu kosong (US-04)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const UsageChartCard(
            title: 'Pemakaian harian',
            rangeLabel: 'November',
            points: [],
          ),
        ),
      );
      expect(find.text('Belum ada data pemakaian'), findsOneWidget);
    });
  });

  testWidgets('RoomCompare urut pemakaian terbesar', (tester) async {
    await tester.pumpWidget(
      _host(
        const RoomCompare(
          periodLabel: 'November',
          entries: [
            RoomCompareEntry(name: 'Kamar 2', liters: 1906),
            RoomCompareEntry(name: 'Kamar 1', liters: 2906),
          ],
        ),
      ),
    );
    final y1 = tester.getTopLeft(find.text('Kamar 1')).dy;
    final y2 = tester.getTopLeft(find.text('Kamar 2')).dy;
    expect(y1, lessThan(y2));
  });

  testWidgets('AlertItem aktivitas tanpa chip status', (tester) async {
    await tester.pumpWidget(
      _host(
        const AlertItem(
          type: AlertItemType.activity,
          status: AlertItemStatus.info,
          title: 'Valve Kamar 2 dibuka',
          subtitle: 'Tombol fisik · Hari ini 14.20',
        ),
      ),
    );
    expect(find.text('Aktif'), findsNothing);
    expect(find.text('Selesai'), findsNothing);
  });

  testWidgets('showConfirmSheet: Batal = false, konfirmasi = true', (
    tester,
  ) async {
    final results = <bool>[];
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => AppButton(
            label: 'Buka sheet',
            onPressed: () async => results.add(
              await showConfirmSheet(
                context,
                action: ConfirmSheetAction.close,
                title: 'Tutup valve Kamar 1?',
                message: 'Air berhenti mengalir.',
                confirmLabel: 'Tutup valve',
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka sheet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Buka sheet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tutup valve'));
    await tester.pumpAndSettle();

    expect(results, [false, true]);
  });

  testWidgets('showToast tampil lalu hilang', (tester) async {
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => AppButton(
            label: 'Toast',
            onPressed: () => showToast(
              context,
              type: ToastType.error,
              message: 'Perangkat tidak merespons. Coba lagi',
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Toast'));
    await tester.pump();
    expect(find.text('Perangkat tidak merespons. Coba lagi'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Perangkat tidak merespons. Coba lagi'), findsNothing);
  });

  testWidgets('galeri merender semua komponen tanpa overflow', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const ComponentGalleryPage()),
    );
    // Gulir sampai bawah; error overflow akan menggagalkan tes.
    await tester.dragUntilVisible(
      find.text('Semua kamar normal'),
      find.byType(ListView),
      const Offset(0, -400),
    );
    expect(find.text('Semua kamar normal'), findsOneWidget);
  });
}
