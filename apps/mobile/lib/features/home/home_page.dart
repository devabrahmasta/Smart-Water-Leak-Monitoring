import 'package:flutter/material.dart';

import '../../core/config/env.dart';
import '../../core/format/formatters.dart';
import '../_placeholder_page.dart';

/// Beranda (US-01 s.d. US-03). Isi lengkap di R-11.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: 'Halo, ${Env.ownerName}',
      subtitle: '${Env.propertyName} · ${formatDayDate(DateTime.now())}',
    );
  }
}
