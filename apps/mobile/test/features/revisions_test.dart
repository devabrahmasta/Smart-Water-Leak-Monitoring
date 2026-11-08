import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:smart_water/components/components.dart';

import '../helpers.dart';

Finder _navTab(String label) =>
    find.descendant(of: find.byType(BottomNav), matching: find.text(label));

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('toast punya Material (tanpa garis bawah kuning)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showToast(
              context,
              type: ToastType.success,
              message: 'Valve Kamar 1 tertutup',
            ),
            child: const Text('tes'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('tes'));
    await tester.pump();
    final text = find.text('Valve Kamar 1 tertutup');
    expect(
      find.ancestor(of: text, matching: find.byType(Material)),
      findsWidgets,
    );
    // Gaya teks tidak boleh jatuh ke gaya debug (dekorasi garis bawah).
    final style = DefaultTextStyle.of(tester.element(text)).style;
    expect(style.decoration, isNot(TextDecoration.underline));
    await tester.pump(const Duration(minutes: 3));
  });

  testWidgets('alert di Detail Kamar: tanpa tombol Lihat kamar', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(_navTab('Kamar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kamar 1').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Riwayat perintah'), 300);
    await tester.scrollUntilVisible(find.text('Alert terakhir'), 300);
    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AlertItem).last);
    await tester.pumpAndSettle();
    expect(find.text('Lihat kamar'), findsNothing);
    expect(find.text('Aturan'), findsOneWidget);
  });

  testWidgets('alert di Notifikasi: tombol Lihat kamar tetap ada', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(_navTab('Notifikasi'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AlertItem).last);
    await tester.pumpAndSettle();
    expect(find.text('Lihat kamar'), findsOneWidget);
  });
}
