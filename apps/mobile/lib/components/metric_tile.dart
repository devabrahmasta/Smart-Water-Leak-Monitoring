import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_tokens.dart';
import 'card_parts.dart';

/// Figma: Components / Metric Tile. Label + angka + satuan.
/// Bila [value] null tampil "Tidak ada data".
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.unit = 'L',
  });

  final String label;

  /// Angka yang sudah diformat, misalnya `4.812`.
  final String? value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return CardSurface(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (value == null)
            Text(
              'Tidak ada data',
              style: AppTextStyles.body.copyWith(color: AppColors.inkMuted),
            )
          else
            ValueWithUnit(value: value!, unit: unit),
        ],
      ),
    );
  }
}
