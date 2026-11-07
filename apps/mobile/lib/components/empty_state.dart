import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_tokens.dart';
import 'card_parts.dart';

/// Figma: Components / Empty State (US-02, US-18).
/// Contoh: "Semua kamar normal", "Belum ada kamar terhubung".
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = AppIcons.success,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return CardSurface(
      child: Row(
        children: [
          IconCircle(
            icon: icon,
            background: AppColors.primarySoft,
            color: AppColors.primaryText,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.headline),
                Text(
                  message,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
