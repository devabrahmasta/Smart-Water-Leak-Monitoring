import 'package:flutter/widgets.dart';

import 'app_colors.dart';

/// Jarak kelipatan 4 dari `docs/DESIGN.md` bagian 4.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Gutter kiri-kanan layar.
  static const double gutter = xl;

  /// Padding dalam kartu.
  static const double cardPadding = xl;

  /// Jarak antar kartu.
  static const double cardGap = md;

  /// Jarak antar seksi.
  static const double sectionGap = xxl;
}

/// Hanya tiga bentuk: kartu 24, pil, lingkaran.
abstract final class AppRadius {
  static const double card = 24;
  static const double pill = 999;

  static const cardAll = BorderRadius.all(Radius.circular(card));
  static const pillAll = BorderRadius.all(Radius.circular(pill));
}

/// Hanya satu bayangan, untuk elemen melayang (nav, sheet, toast).
abstract final class AppShadows {
  static const float = [
    BoxShadow(
      color: Color(0x1A16181C), // ink 10%
      offset: Offset(0, 8),
      blurRadius: 24,
    ),
  ];
}

/// Ukuran ikon dan sentuhan.
abstract final class AppSizes {
  static const double iconInline = 20;
  static const double iconNav = 24;
  static const double iconChip = 14;
  static const double iconContainer = 40;
  static const double minTouch = 44;

  /// Animasi tekan: skala 0,97, 150 ms.
  static const double pressScale = 0.97;
  static const pressDuration = Duration(milliseconds: 150);
}

/// Gradien biru di belakang header Beranda (satu-satunya gradien yang boleh).
abstract final class AppGradients {
  static const double homeHeaderHeight = 340;

  static final homeHeader = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: const [0, 0.45, 1],
    colors: [
      AppColors.primary.withValues(alpha: 0.55),
      AppColors.primary.withValues(alpha: 0.16),
      AppColors.primary.withValues(alpha: 0),
    ],
  );
}
