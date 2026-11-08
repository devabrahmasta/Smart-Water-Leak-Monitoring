import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_tokens.dart';

enum StatusChipType {
  normal,
  leak,

  /// Bocor di atas kartu `danger-soft` (chip `danger` supaya tetap terlihat).
  leakOnSoft,
  closed,

  /// Valve tertutup di atas kartu gelap (chip terang).
  closedOnDark,
  offline,
  highest,
}

/// Figma: Components / Status Chip. Tinggi 28, ikon 14 + label.
/// Status selalu ditulis dengan teks dan ikon; warna hanya penguat.
class StatusChip extends StatelessWidget {
  const StatusChip(this.type, {super.key});

  final StatusChipType type;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon, label) = switch (type) {
      StatusChipType.normal => (
        AppColors.primarySoft,
        AppColors.primaryText,
        AppIcons.check,
        'Normal',
      ),
      StatusChipType.leak => (
        AppColors.dangerSoft,
        AppColors.dangerText,
        AppIcons.alert,
        'Bocor',
      ),
      StatusChipType.leakOnSoft => (
        AppColors.danger,
        AppColors.onPrimary,
        AppIcons.alert,
        'Bocor',
      ),
      StatusChipType.closed => (
        AppColors.ink,
        AppColors.onDark,
        AppIcons.lock,
        'Air dimatikan',
      ),
      StatusChipType.closedOnDark => (
        AppColors.bg,
        AppColors.ink,
        AppIcons.lock,
        'Air dimatikan',
      ),
      StatusChipType.offline => (
        AppColors.surfaceStrong,
        AppColors.inkMuted,
        AppIcons.offline,
        'Offline',
      ),
      StatusChipType.highest => (
        AppColors.bg,
        AppColors.ink,
        AppIcons.highest,
        'Tertinggi',
      ),
    };

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.pillAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSizes.iconChip, color: fg),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

enum TagTone { danger, primary, neutral }

/// Chip kecil tanpa ikon untuk status alert (Aktif / Selesai) di Alert Item.
class StatusTag extends StatelessWidget {
  const StatusTag({super.key, required this.label, required this.tone});

  final String label;
  final TagTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      TagTone.danger => (AppColors.dangerSoft, AppColors.dangerText),
      TagTone.primary => (AppColors.primarySoft, AppColors.primaryText),
      TagTone.neutral => (AppColors.surfaceStrong, AppColors.inkMuted),
    };
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.pillAll),
      // widthFactor 1: tengah vertikal tanpa melebar memenuhi baris.
      child: Center(
        widthFactor: 1,
        child: Text(label, style: AppTextStyles.label.copyWith(color: fg)),
      ),
    );
  }
}
