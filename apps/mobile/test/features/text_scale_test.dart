import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:smart_water/components/components.dart';
import 'package:smart_water/data/mock/mock_smart_water_repository.dart';

import '../helpers.dart';

Finder _navTab(String label) =>
    find.descendant(of: find.byType(BottomNav), matching: find.text(label));

/// Ukuran teks besar (pengaturan aksesibilitas HP) tidak boleh membuat
/// layar overflow. Overflow otomatis menggagalkan tes.
void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  for (final scale in [1.3, 1.6]) {
    for (final scenario in [MockScenario.standard, MockScenario.offline]) {
      testWidgets('teks ${scale}x, skenario ${scenario.name}', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await pumpApp(tester, scenario: scenario);
        await tester.tap(find.text('Lihat grafik'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bulanan'));
        await tester.pumpAndSettle();

        await tester.tap(_navTab('Kamar'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(RoomCard).first);
        await tester.pumpAndSettle();

        await tester.tap(_navTab('Notifikasi'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(AlertItem).first);
        await tester.pumpAndSettle();
      });
    }
  }
}
