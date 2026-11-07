import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_tokens.dart';
import 'card_parts.dart';

/// Sumber perintah sesuai kontrak: APP, AUTO, MANUAL_BUTTON.
enum CommandSource { app, auto, manualButton }

/// Status perintah sesuai kontrak: PENDING, SUCCESS, FAILED.
enum CommandResult { success, pending, failed }

/// Figma: Components / Command Row (US-06, US-10).
class CommandRow extends StatelessWidget {
  const CommandRow({
    super.key,
    required this.action,
    required this.source,
    required this.time,
    required this.result,
  });

  /// "Buka valve" / "Tutup valve".
  final String action;
  final CommandSource source;

  /// Waktu sudah diformat, misalnya "08.05".
  final String time;
  final CommandResult result;

  static String sourceLabel(CommandSource source) => switch (source) {
    CommandSource.app => 'Aplikasi',
    CommandSource.auto => 'Otomatis',
    CommandSource.manualButton => 'Tombol fisik',
  };

  @override
  Widget build(BuildContext context) {
    final sourceIcon = switch (source) {
      CommandSource.app => AppIcons.app,
      CommandSource.auto => AppIcons.auto,
      CommandSource.manualButton => AppIcons.manualButton,
    };
    final (IconData resultIcon, Color color, String label) = switch (result) {
      CommandResult.success => (
        AppIcons.check,
        AppColors.primaryText,
        'Berhasil',
      ),
      CommandResult.pending => (AppIcons.clock, AppColors.inkMuted, 'Menunggu'),
      CommandResult.failed => (AppIcons.close, AppColors.dangerText, 'Gagal'),
    };

    return Semantics(
      label: '$action, ${sourceLabel(source)}, $time, $label',
      excludeSemantics: true,
      child: CardSurface(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md - 2,
        ),
        child: Row(
          children: [
            IconCircle(icon: sourceIcon),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(action, style: AppTextStyles.label),
                  Text(
                    '${sourceLabel(source)} · $time',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(resultIcon, size: 16, color: color),
            const SizedBox(width: AppSpacing.xs),
            Text(label, style: AppTextStyles.label.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
