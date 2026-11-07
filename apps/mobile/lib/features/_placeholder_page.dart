import 'package:flutter/material.dart';

import '../core/router/app_shell.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_tokens.dart';

/// Layar sementara R-09. Diganti layar asli di R-11, lalu file ini dihapus.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

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
          Text(title, style: AppTextStyles.title),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle!,
              style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted),
            ),
          ],
        ],
      ),
    );
  }
}
