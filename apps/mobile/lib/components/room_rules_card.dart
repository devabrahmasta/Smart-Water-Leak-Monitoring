import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_tokens.dart';
import 'card_parts.dart';
import 'pressable.dart';

/// Satu aturan di [RoomRulesCard]. Diketuk untuk diubah sendiri-sendiri.
class RoomRuleRow {
  const RoomRuleRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
}

/// Ambang aturan kebocoran di Detail Kamar.
class RoomRulesCard extends StatelessWidget {
  const RoomRulesCard({super.key, required this.rows});

  final List<RoomRuleRow> rows;

  @override
  Widget build(BuildContext context) {
    return CardSurface(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPadding,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final row in rows) _Row(row: row)],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row});

  final RoomRuleRow row;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: row.onTap,
      semanticLabel: 'Ubah ${row.label}, sekarang ${row.value}',
      builder: (context, pressed) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.minTouch + 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    row.label,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                  Text(row.value, style: AppTextStyles.label),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(
              AppIcons.forward,
              size: AppSizes.iconInline,
              color: AppColors.inkMuted,
            ),
          ],
        ),
      ),
    );
  }
}
