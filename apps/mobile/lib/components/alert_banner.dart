import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_tokens.dart';
import 'app_button.dart';
import 'card_parts.dart';

enum AlertBannerType { leak, anomaly }

/// Figma: Components / Alert Banner (US-03). Varian Kebocoran (merah)
/// dan Anomali (netral), dengan tombol Lihat.
class AlertBanner extends StatelessWidget {
  const AlertBanner({
    super.key,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.onView,
  });

  final AlertBannerType type;

  /// Contoh: "Kebocoran di Kamar 2".
  final String title;

  /// Contoh: "Valve ditutup otomatis · 02.14" atau "+2 lainnya".
  final String subtitle;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final leak = type == AlertBannerType.leak;
    final fg = leak ? AppColors.dangerText : AppColors.ink;
    final sub = leak ? AppColors.dangerText : AppColors.inkMuted;

    return CardSurface(
      color: leak ? AppColors.dangerSoft : AppColors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: Row(
        children: [
          IconCircle(icon: leak ? AppIcons.alert : AppIcons.anomaly, color: fg),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headline.copyWith(color: fg),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(color: sub),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          AppButton(
            label: 'Lihat',
            size: AppButtonSize.medium,
            style: leak ? AppButtonStyle.danger : AppButtonStyle.primary,
            onPressed: onView,
          ),
        ],
      ),
    );
  }
}
