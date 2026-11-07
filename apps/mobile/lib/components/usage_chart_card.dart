import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/format/formatters.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_tokens.dart';
import 'card_parts.dart';

/// Satu bar di [UsageChartCard].
class ChartPoint {
  const ChartPoint({required this.label, required this.liters});

  /// Label sumbu x yang sudah diformat: `4` (harian) atau `Okt` (bulanan).
  final String label;
  final double liters;
}

/// Figma: Components / Usage Chart Card (US-04, US-06). Variant harian dan
/// bulanan hanya beda isi [title], [rangeLabel], dan [points].
///
/// Bar tertinggi biru dengan label nilai. Tap bar lain menampilkan nilainya.
/// Tanpa data: teks "Belum ada data pemakaian", bukan sumbu kosong.
class UsageChartCard extends StatefulWidget {
  const UsageChartCard({
    super.key,
    required this.title,
    required this.rangeLabel,
    required this.points,
  });

  /// "Pemakaian harian" / "Pemakaian bulanan".
  final String title;

  /// "1 sampai 6 Nov" / "Jun sampai Nov".
  final String rangeLabel;
  final List<ChartPoint> points;

  @override
  State<UsageChartCard> createState() => _UsageChartCardState();
}

class _UsageChartCardState extends State<UsageChartCard> {
  int? _selected;

  static const double _plotHeight = 96;
  static const double _valueLabelHeight = 24;

  @override
  void didUpdateWidget(UsageChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points) _selected = null;
  }

  int? get _peak {
    final points = widget.points;
    if (points.isEmpty) return null;
    var peak = 0;
    for (var i = 1; i < points.length; i++) {
      if (points[i].liters > points[peak].liters) peak = i;
    }
    return points[peak].liters > 0 ? peak : null;
  }

  bool get _hasData => widget.points.any((p) => p.liters > 0);

  @override
  Widget build(BuildContext context) {
    return CardSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(widget.title, style: AppTextStyles.headline),
              ),
              Text(
                widget.rangeLabel,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: _valueLabelHeight + _plotHeight + AppSpacing.sm + 18,
            child: _hasData
                ? _buildBars()
                : Center(
                    child: Text(
                      'Belum ada data pemakaian',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBars() {
    final points = widget.points;
    final peak = _peak;
    final labelled = _selected ?? peak;
    final maxValue = points.fold<double>(0, (m, p) => math.max(m, p.liters));
    final dense = points.length > 12;

    return LayoutBuilder(
      builder: (context, constraints) {
        final slot = constraints.maxWidth / points.length;
        final barWidth = math.min(28.0, slot * 0.6);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < points.length; i++)
              SizedBox(
                width: slot,
                child: _Bar(
                  point: points[i],
                  width: barWidth,
                  heightFactor: maxValue <= 0 ? 0 : points[i].liters / maxValue,
                  plotHeight: _plotHeight,
                  isPeak: i == peak,
                  isSelected: i == _selected && i != peak,
                  showValue: i == labelled,
                  showAxisLabel:
                      !dense ||
                      i == labelled ||
                      i == 0 ||
                      i == points.length - 1 ||
                      (i + 1) % 5 == 0,
                  emphasize: i == labelled,
                  onTap: () =>
                      setState(() => _selected = _selected == i ? null : i),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.point,
    required this.width,
    required this.heightFactor,
    required this.plotHeight,
    required this.isPeak,
    required this.isSelected,
    required this.showValue,
    required this.showAxisLabel,
    required this.emphasize,
    required this.onTap,
  });

  final ChartPoint point;
  final double width;
  final double heightFactor;
  final double plotHeight;
  final bool isPeak;
  final bool isSelected;
  final bool showValue;
  final bool showAxisLabel;
  final bool emphasize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isPeak
        ? AppColors.primary
        : (isSelected ? AppColors.primarySoft : AppColors.surfaceStrong);
    // Bar nol tetap tampil sebagai pil pendek supaya harinya terlihat.
    final barHeight = math.max(width * 0.8, heightFactor * plotHeight);

    return Semantics(
      button: true,
      label: '${point.label}: ${formatLiters(point.liters)}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SizedBox(
              height: 24,
              child: showValue
                  ? OverflowBox(
                      maxWidth: 96,
                      child: Text(
                        formatLiters(point.liters),
                        maxLines: 1,
                        style: AppTextStyles.label,
                      ),
                    )
                  : null,
            ),
            SizedBox(
              height: plotHeight,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedContainer(
                  duration: AppSizes.pressDuration,
                  width: width,
                  height: barHeight,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: AppRadius.pillAll,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 18,
              child: showAxisLabel
                  ? OverflowBox(
                      maxWidth: 48,
                      child: Text(
                        point.label,
                        maxLines: 1,
                        style: emphasize
                            ? AppTextStyles.label
                            : AppTextStyles.caption.copyWith(
                                color: AppColors.inkMuted,
                              ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
