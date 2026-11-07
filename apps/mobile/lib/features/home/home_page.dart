import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../core/config/env.dart';
import '../../core/format/formatters.dart';
import '../../core/router/app_router.dart';
import '../../core/router/app_shell.dart';
import '../../core/theme/app_tokens.dart';

/// Beranda (US-01 s.d. US-03). Isi lengkap di R-11.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.xxl,
          AppSpacing.gutter,
          AppShell.contentBottomInset,
        ),
        children: [
          ScreenHeader.home(
            title: 'Halo, ${Env.ownerName}',
            subtitle: '${Env.propertyName} · ${formatDayDate(DateTime.now())}',
            onBell: () => context.go(AppRoutes.alerts),
          ),
          // Jalan pintas sementara ke galeri komponen (debug saja).
          if (kDebugMode) ...[
            const SizedBox(height: AppSpacing.sectionGap),
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                label: 'Galeri komponen',
                style: AppButtonStyle.secondary,
                size: AppButtonSize.medium,
                onPressed: () => context.push(AppRoutes.gallery),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
