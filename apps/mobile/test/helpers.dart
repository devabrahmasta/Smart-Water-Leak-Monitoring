import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_water/app.dart';
import 'package:smart_water/data/mock/mock_smart_water_repository.dart';
import 'package:smart_water/data/providers/providers.dart';

/// Pasang aplikasi lengkap dengan repository mock tanpa jeda, polling mati,
/// dan tanpa retry otomatis (supaya tidak ada timer tertinggal di tes).
Future<MockSmartWaterRepository> pumpApp(
  WidgetTester tester, {
  MockScenario scenario = MockScenario.standard,
}) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final repo = MockSmartWaterRepository(
    scenario: scenario,
    latency: Duration.zero,
    ackDelay: const Duration(milliseconds: 10),
  );
  await tester.pumpWidget(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        pollIntervalProvider.overrideWithValue(null),
      ],
      child: const SmartWaterApp(),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}
