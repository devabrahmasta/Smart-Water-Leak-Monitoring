import 'package:flutter/material.dart';

import '../core/format/formatters.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_tokens.dart';
import 'card_parts.dart';

/// Figma: Components / Status Tally (US-02). Tiga angka dalam satu kartu.
class StatusTally extends StatelessWidget {
  const StatusTally({
    super.key,
    required this.normal,
    required this.closed,
    required this.offline,
  });

  final int normal;
  final int closed;
  final int offline;

  @override
  Widget build(BuildContext context) {
    return CardSurface(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.lg,
        horizontal: AppSpacing.md,
      ),
      child: Row(
        children: [
          _Cell(value: normal, label: 'Normal'),
          _Cell(value: closed, label: 'Valve tertutup'),
          _Cell(value: offline, label: 'Offline'),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: '$value $label',
        excludeSemantics: true,
        child: Column(
          children: [
            Text(formatNumber(value), style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
