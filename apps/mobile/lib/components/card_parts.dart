import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_tokens.dart';
import 'pressable.dart';

/// Bagian bersama yang dipakai banyak komponen. Bukan komponen Figma
/// sendiri, jadi jangan dipakai langsung di layar.

/// Kartu radius 24 tanpa border dan tanpa bayangan.
class CardSurface extends StatelessWidget {
  const CardSurface({
    super.key,
    required this.child,
    this.color = AppColors.surface,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(color: color, borderRadius: AppRadius.cardAll),
      child: child,
    );
    if (onTap == null) return box;
    return Pressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      builder: (context, pressed) => box,
    );
  }
}

/// Wadah ikon lingkaran (default 40).
class IconCircle extends StatelessWidget {
  const IconCircle({
    super.key,
    required this.icon,
    this.background = AppColors.bg,
    this.color = AppColors.ink,
    this.size = AppSizes.iconContainer,
  });

  final IconData icon;
  final Color background;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(icon, size: AppSizes.iconInline, color: color),
    );
  }
}

/// Angka + satuan kecil di sampingnya, misalnya `142 L`, `6,4 L/menit`.
class ValueWithUnit extends StatelessWidget {
  const ValueWithUnit({
    super.key,
    required this.value,
    required this.unit,
    this.valueStyle,
    this.unitStyle,
    this.color = AppColors.ink,
    this.unitColor = AppColors.inkMuted,
  });

  final String value;
  final String unit;
  final TextStyle? valueStyle;

  /// Default Label 13 SemiBold. Summary Card memakai yang lebih besar.
  final TextStyle? unitStyle;
  final Color color;
  final Color unitColor;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: value,
            style: (valueStyle ?? AppTextStyles.title).copyWith(color: color),
          ),
          // Jarak angka-satuan memakai ukuran angka tanpa letter spacing,
          // supaya Display (-2) tidak menempelkan satuan.
          TextSpan(
            text: ' ',
            style: (valueStyle ?? AppTextStyles.title).copyWith(
              letterSpacing: 0,
              fontSize:
                  ((valueStyle ?? AppTextStyles.title).fontSize ?? 22) * 0.3,
            ),
          ),
          TextSpan(
            text: unit,
            style: (unitStyle ?? AppTextStyles.unit).copyWith(color: unitColor),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
