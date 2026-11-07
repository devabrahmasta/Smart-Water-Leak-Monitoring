import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/format/formatters.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_tokens.dart';
import 'card_parts.dart';
import 'pressable.dart';

/// Figma: Components / Summary Card (US-01). Kartu `primary`: total hari ini
/// (Display), total bulan ini, 7 bar mini harian (bar terakhir = hari ini).
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.todayLiters,
    required this.monthLiters,
    required this.last7DaysLiters,
    required this.onSeeChart,
  });

  final double todayLiters;
  final double monthLiters;

  /// 7 nilai, urut dari 6 hari lalu sampai hari ini.
  final List<double> last7DaysLiters;
  final VoidCallback onSeeChart;

  @override
  Widget build(BuildContext context) {
    const onPrimary = AppColors.onPrimary;
    return CardSurface(
      color: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pemakaian hari ini',
                      style: AppTextStyles.label.copyWith(color: onPrimary),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ValueWithUnit(
                      value: formatNumber(todayLiters.round()),
                      unit: 'L',
                      valueStyle: AppTextStyles.display,
                      unitStyle: AppTextStyles.headline,
                      color: onPrimary,
                      unitColor: onPrimary,
                    ),
                  ],
                ),
              ),
              _MiniBars(values: last7DaysLiters),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Bulan ini  ${formatLiters(monthLiters.round())}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label.copyWith(color: onPrimary),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Pressable(
                onTap: onSeeChart,
                semanticLabel: 'Lihat grafik',
                builder: (context, pressed) => SizedBox(
                  height: AppSizes.minTouch,
                  child: Row(
                    children: [
                      Text(
                        'Lihat grafik',
                        style: AppTextStyles.label.copyWith(color: onPrimary),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      const Icon(AppIcons.forward, size: 16, color: onPrimary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniBars extends StatelessWidget {
  const _MiniBars({required this.values});

  final List<double> values;

  static const double _maxHeight = 56;
  static const double _barWidth = 8;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<double>(0, math.max);
    return Semantics(
      label: 'Pemakaian 7 hari terakhir',
      excludeSemantics: true,
      child: SizedBox(
        height: _maxHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < values.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Container(
                width: _barWidth,
                // Minimal setinggi lebarnya supaya tampil sebagai titik.
                height: maxValue <= 0
                    ? _barWidth
                    : math.max(_barWidth, values[i] / maxValue * _maxHeight),
                decoration: BoxDecoration(
                  color: i == values.length - 1
                      ? AppColors.onPrimary
                      : AppColors.onPrimary.withValues(alpha: 0.5),
                  borderRadius: AppRadius.pillAll,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
