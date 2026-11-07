import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_tokens.dart';

/// Figma: Components / Segmented Control. Pil `surface` tinggi 44,
/// segmen aktif pil `bg` dengan label `ink`, segmen lain `ink-muted`.
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  /// Nilai dan label per segmen, urut tampil (2 atau 3 segmen).
  final List<(T, String)> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Flexible supaya label memendek (ellipsis) di layar sempit atau
          // ukuran teks besar, bukan overflow.
          for (final (value, label) in segments)
            Flexible(
              child: _Segment(
                label: label,
                selected: value == selected,
                onTap: () {
                  if (value != selected) onChanged(value);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppSizes.pressDuration,
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            color: selected ? AppColors.bg : AppColors.surface,
            borderRadius: AppRadius.pillAll,
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label.copyWith(
                color: selected ? AppColors.ink : AppColors.inkMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
