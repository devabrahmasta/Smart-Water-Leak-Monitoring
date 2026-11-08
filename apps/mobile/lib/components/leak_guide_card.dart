import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_tokens.dart';
import 'app_button.dart';
import 'card_parts.dart';

/// Panduan kebocoran di Detail Kamar: kenapa terdeteksi bocor dan apa yang
/// sebaiknya dilakukan. Kartu `danger-soft`, teks `danger-text` / `ink`.
class LeakGuideCard extends StatelessWidget {
  const LeakGuideCard({
    super.key,
    required this.why,
    required this.steps,
    this.onOpenValve,
  });

  final String why;
  final List<String> steps;

  /// Null = tombol tidak ditampilkan (mis. perangkat offline).
  final VoidCallback? onOpenValve;

  @override
  Widget build(BuildContext context) {
    final muted = AppTextStyles.body.copyWith(color: AppColors.ink);
    return CardSurface(
      color: AppColors.dangerSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                AppIcons.alert,
                size: AppSizes.iconInline,
                color: AppColors.dangerText,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Kenapa terdeteksi bocor',
                  style: AppTextStyles.headline.copyWith(
                    color: AppColors.dangerText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(why, style: muted),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Yang sebaiknya dilakukan',
            style: AppTextStyles.headline.copyWith(color: AppColors.dangerText),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: AppSpacing.xl,
                    child: Text(
                      '${i + 1}.',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.dangerText,
                      ),
                    ),
                  ),
                  Expanded(child: Text(steps[i], style: muted)),
                ],
              ),
            ),
          if (onOpenValve != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Sudah aman, nyalakan air',
              style: AppButtonStyle.secondary,
              expand: true,
              onPressed: onOpenValve,
            ),
          ],
        ],
      ),
    );
  }
}
