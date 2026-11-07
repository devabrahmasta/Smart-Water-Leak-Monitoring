import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import 'pressable.dart';

/// Figma: Components / Icon Button. Lingkaran 44 `surface`, ikon `ink`,
/// titik badge `danger` opsional.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.badge = false,
    this.background = AppColors.surface,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final bool badge;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPressed,
      semanticLabel: semanticLabel,
      builder: (context, pressed) => AnimatedContainer(
        duration: AppSizes.pressDuration,
        width: AppSizes.minTouch,
        height: AppSizes.minTouch,
        decoration: BoxDecoration(
          color: pressed ? AppColors.surfaceStrong : background,
          shape: BoxShape.circle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: AppSizes.iconInline, color: AppColors.ink),
            if (badge)
              Positioned(
                top: 10,
                right: 11,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
