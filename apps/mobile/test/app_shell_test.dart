import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:smart_water/components/bottom_nav.dart';
import 'package:smart_water/core/theme/app_colors.dart';

import 'helpers.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('kriteria R-09: 3 tab tampil dan bisa dipindah', (tester) async {
    await pumpApp(tester);

    expect(find.byType(BottomNav), findsOneWidget);
    expect(find.textContaining('Halo,'), findsOneWidget);

    await tester.tap(
      find.descendant(of: find.byType(BottomNav), matching: find.text('Kamar')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Halo,'), findsNothing);
    expect(find.text('Perlu dicek'), findsOneWidget); // segmen filter

    await tester.tap(
      find.descendant(
        of: find.byType(BottomNav),
        matching: find.text('Notifikasi'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Aktif'), findsWidgets);
  });

  testWidgets('tema memakai token DESIGN.md', (tester) async {
    await pumpApp(tester);
    final theme = Theme.of(tester.element(find.byType(BottomNav)));

    expect(theme.scaffoldBackgroundColor, AppColors.bg);
    expect(theme.colorScheme.primary, AppColors.primary);
    expect(theme.textTheme.titleLarge?.fontFamily, 'PlusJakartaSans');
    expect(theme.textTheme.titleLarge?.fontSize, 22);
  });

  testWidgets('badge disembunyikan saat 0 atau saat tabnya aktif', (
    tester,
  ) async {
    Widget nav(int current, int count) => MaterialApp(
      home: Scaffold(
        body: BottomNav(
          currentIndex: current,
          onTap: (_) {},
          badgeIndex: 2,
          badgeCount: count,
        ),
      ),
    );

    await tester.pumpWidget(nav(0, 3));
    expect(find.text('3'), findsOneWidget);

    await tester.pumpWidget(nav(0, 0));
    expect(find.text('0'), findsNothing);

    await tester.pumpWidget(nav(2, 3));
    expect(find.text('3'), findsNothing);
  });
}
