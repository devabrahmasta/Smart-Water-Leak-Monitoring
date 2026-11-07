import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/format/formatters.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_tokens.dart';
import 'card_parts.dart';

class RoomCompareEntry {
  const RoomCompareEntry({required this.name, required this.liters});

  final String name;
  final double liters;
}

/// Figma: Components / Room Compare (US-04). Semua kamar urut pemakaian
/// terbesar. Bar teratas `primary`, sisanya `ink`, di atas track
/// `surface-strong`.
class RoomCompare extends StatelessWidget {
  const RoomCompare({
    super.key,
    required this.entries,
    required this.periodLabel,
  });

  final List<RoomCompareEntry> entries;

  /// "November" atau "6 bulan terakhir".
  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    final sorted = [...entries]..sort((a, b) => b.liters.compareTo(a.liters));
    final maxValue = sorted.isEmpty ? 0.0 : sorted.first.liters;

    return CardSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Per kamar', style: AppTextStyles.headline)),
              Text(
                periodLabel,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
          if (sorted.isEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Belum ada data pemakaian',
              style: AppTextStyles.body.copyWith(color: AppColors.inkMuted),
            ),
          ],
          for (var i = 0; i < sorted.length; i++) ...[
            SizedBox(height: i == 0 ? AppSpacing.lg : AppSpacing.md),
            _Row(
              entry: sorted[i],
              fraction: maxValue <= 0 ? 0 : sorted[i].liters / maxValue,
              top: i == 0,
            ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry, required this.fraction, required this.top});

  final RoomCompareEntry entry;
  final double fraction;
  final bool top;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${entry.name}: ${formatLiters(entry.liters)}',
      excludeSemantics: true,
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              entry.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label,
            ),
          ),
          Expanded(
            child: Container(
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.surfaceStrong,
                borderRadius: AppRadius.pillAll,
              ),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: math.max(0.02, fraction.clamp(0, 1)),
                child: Container(
                  decoration: BoxDecoration(
                    color: top ? AppColors.primary : AppColors.ink,
                    borderRadius: AppRadius.pillAll,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 84,
            child: Text(
              formatLiters(entry.liters.round()),
              textAlign: TextAlign.right,
              maxLines: 1,
              style: AppTextStyles.label,
            ),
          ),
        ],
      ),
    );
  }
}
