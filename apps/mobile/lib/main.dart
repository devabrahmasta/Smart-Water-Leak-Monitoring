import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app.dart';
import 'core/push/push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'id_ID';
  await initializeDateFormatting('id_ID');

  final container = ProviderContainer();
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const SmartWaterApp(),
    ),
  );
  // Disiapkan setelah UI tampil supaya pembukaan aplikasi tidak tertahan.
  PushService(container).start();
}
