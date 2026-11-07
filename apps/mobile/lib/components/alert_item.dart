import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_tokens.dart';
import 'card_parts.dart';
import 'status_chip.dart';

/// Tipe alert sesuai kontrak: LEAK, ANOMALY, ACTIVITY.
enum AlertItemType { leak, anomaly, activity }

/// Status alert sesuai kontrak: OPEN, RESOLVED, INFO.
enum AlertItemStatus { open, resolved, info }

/// Figma: Components / Alert Item (US-11).
/// Variant: kebocoran/anomali × aktif/selesai, dan aktivitas (tanpa chip).
class AlertItem extends StatelessWidget {
  const AlertItem({
    super.key,
    required this.type,
    required this.status,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final AlertItemType type;
  final AlertItemStatus status;

  /// "Kebocoran di Kamar 2", "Pemakaian tidak wajar", "Valve Kamar 2 dibuka".
  final String title;

  /// "Aliran stabil 6 menit · Hari ini 02.14".
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final open = status == AlertItemStatus.open;

    final (IconData icon, Color circle, Color iconColor) = switch ((
      type,
      status,
    )) {
      (AlertItemType.activity, _) => (
        AppIcons.manualButton,
        AppColors.bg,
        AppColors.ink,
      ),
      (_, AlertItemStatus.resolved) => (
        AppIcons.success,
        AppColors.bg,
        AppColors.inkMuted,
      ),
      (AlertItemType.leak, _) => (
        AppIcons.alert,
        AppColors.dangerSoft,
        AppColors.dangerText,
      ),
      (AlertItemType.anomaly, _) => (
        AppIcons.anomaly,
        AppColors.bg,
        AppColors.ink,
      ),
    };

    final tag = switch (status) {
      AlertItemStatus.info => null,
      AlertItemStatus.resolved => const StatusTag(
        label: 'Selesai',
        tone: TagTone.neutral,
      ),
      AlertItemStatus.open => StatusTag(
        label: 'Aktif',
        tone: type == AlertItemType.leak ? TagTone.danger : TagTone.primary,
      ),
    };

    return CardSurface(
      onTap: onTap,
      semanticLabel: '$title. $subtitle${open ? '. Aktif' : ''}',
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconCircle(icon: icon, background: circle, color: iconColor),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headline,
                ),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
                if (tag != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  tag,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
