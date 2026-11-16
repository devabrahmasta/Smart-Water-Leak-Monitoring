import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_water/components/components.dart';
import 'package:smart_water/core/router/app_router.dart';
import 'package:smart_water/features/home/home_page.dart';

import '../helpers.dart';

void main() {
  Future<void> openFlow(WidgetTester tester) async {
    await pumpApp(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomePage)),
    );
    container.read(routerProvider).go('${AppRoutes.homeRoom(1)}/aliran');
    await tester.pumpAndSettle();
  }

  testWidgets('grafik aliran per jam, diketuk jadi per menit', (tester) async {
    await openFlow(tester);
    expect(find.text('Rata-rata per jam'), findsOneWidget);
    expect(find.text('6,4 L/menit'), findsOneWidget); // debit sekarang

    await tester.tap(find.bySemanticsLabel(RegExp(r'^07: ')));
    await tester.pumpAndSettle();
    expect(find.text('Rata-rata per menit'), findsOneWidget);
    expect(find.text('07.00 sampai 08.00'), findsOneWidget);

    await tester.tap(find.text('Kembali ke per jam'));
    await tester.pumpAndSettle();
    expect(find.text('Rata-rata per jam'), findsOneWidget);
  });

  testWidgets('Detail Kamar membuka grafik aliran', (tester) async {
    await pumpApp(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomePage)),
    );
    container.read(routerProvider).go(AppRoutes.homeRoom(1));
    await tester.pumpAndSettle();
    // Geser secukupnya supaya tombol berada di tengah layar, bukan di bawah nav.
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lihat aliran per jam'));
    await tester.pumpAndSettle();
    expect(find.byType(UsageChartCard), findsOneWidget);
    expect(find.text('Rata-rata per jam'), findsOneWidget);
  });
}
