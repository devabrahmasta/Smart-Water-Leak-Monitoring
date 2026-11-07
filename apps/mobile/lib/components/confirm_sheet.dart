import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_tokens.dart';
import 'app_button.dart';

enum ConfirmSheetAction {
  /// Buka valve: tombol primary.
  open,

  /// Tutup valve: tombol danger.
  close,
}

/// Figma: Components / Confirm Sheet (US-07, US-08). Sheet melayang
/// dengan judul, penjelasan, tombol Batal dan tombol aksi.
class ConfirmSheet extends StatelessWidget {
  const ConfirmSheet({
    super.key,
    required this.action,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.onConfirm,
    required this.onCancel,
  });

  final ConfirmSheetAction action;
  final String title;
  final String message;
  final String confirmLabel;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: AppRadius.cardAll,
        boxShadow: AppShadows.float,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: const BoxDecoration(
                color: AppColors.surfaceStrong,
                borderRadius: AppRadius.pillAll,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            header: true,
            child: Text(title, style: AppTextStyles.headline),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: AppTextStyles.body.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Batal',
                  style: AppButtonStyle.secondary,
                  expand: true,
                  onPressed: onCancel,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton(
                  label: confirmLabel,
                  style: action == ConfirmSheetAction.open
                      ? AppButtonStyle.primary
                      : AppButtonStyle.danger,
                  expand: true,
                  onPressed: onConfirm,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tampilkan [ConfirmSheet] di atas scrim. Mengembalikan `true` bila
/// dikonfirmasi, `false` bila batal atau ditutup.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required ConfirmSheetAction action,
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: AppColors.ink.withValues(alpha: 0.4),
    builder: (context) => SafeArea(
      minimum: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.xxl,
      ),
      child: ConfirmSheet(
        action: action,
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        onConfirm: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    ),
  );
  return result ?? false;
}
