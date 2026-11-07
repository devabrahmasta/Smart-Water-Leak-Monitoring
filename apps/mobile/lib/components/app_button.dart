import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_tokens.dart';
import 'pressable.dart';

enum AppButtonStyle { primary, secondary, danger }

enum AppButtonSize {
  /// Tinggi 52, label Button 15.
  large,

  /// Tinggi 44, label Label 13.
  medium,
}

/// Figma: Components / Button.
/// Variant: primary, secondary, danger · L, M · default, pressed, disabled,
/// loading. Disabled = `onPressed` null. Loading = [loading] true.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = AppButtonStyle.primary,
    this.size = AppButtonSize.large,
    this.icon,
    this.loading = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonStyle style;
  final AppButtonSize size;
  final IconData? icon;
  final bool loading;

  /// Lebar penuh (dipakai di Confirm Sheet).
  final bool expand;

  bool get _enabled => onPressed != null && !loading;

  ({Color bg, Color pressed, Color fg}) get _colors => switch (style) {
    AppButtonStyle.primary => (
      bg: AppColors.primary,
      pressed: AppColors.primaryPress,
      fg: AppColors.onPrimary,
    ),
    AppButtonStyle.secondary => (
      bg: AppColors.surface,
      pressed: AppColors.surfaceStrong,
      fg: AppColors.ink,
    ),
    AppButtonStyle.danger => (
      bg: AppColors.danger,
      pressed: AppColors.dangerText,
      fg: AppColors.onPrimary,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final large = size == AppButtonSize.large;
    final colors = _colors;
    // Disabled memakai surface + ink-subtle untuk semua style (Figma).
    final disabled = onPressed == null;
    final fg = disabled ? AppColors.inkSubtle : colors.fg;
    final text = (large ? AppTextStyles.button : AppTextStyles.label).copyWith(
      color: fg,
    );

    return Pressable(
      onTap: _enabled ? onPressed : null,
      semanticLabel: label,
      builder: (context, pressed) {
        final bg = disabled
            ? AppColors.surface
            : (pressed ? colors.pressed : colors.bg);
        return AnimatedContainer(
          duration: AppSizes.pressDuration,
          height: large ? 52 : 44,
          width: expand ? double.infinity : null,
          padding: EdgeInsets.symmetric(
            horizontal: large ? AppSpacing.xxl : AppSpacing.lg,
          ),
          decoration: BoxDecoration(color: bg, borderRadius: AppRadius.pillAll),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                SizedBox.square(
                  dimension: large ? 18 : 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    strokeCap: StrokeCap.round,
                    color: fg,
                  ),
                )
              else if (icon != null)
                Icon(icon, size: large ? 20 : 18, color: fg),
              if (loading || icon != null) const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  label,
                  style: text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
