import 'package:flutter/painting.dart';

import 'app_colors.dart';

/// Tipografi dari `docs/DESIGN.md` bagian 3. Satu keluarga, angka tabular.
abstract final class AppTextStyles {
  static const fontFamily = 'PlusJakartaSans';

  static const _tabular = [FontFeature.tabularFigures()];

  static TextStyle _style(
    double size,
    double lineHeight,
    FontWeight weight, {
    double letterSpacing = 0,
  }) => TextStyle(
    fontFamily: fontFamily,
    fontSize: size,
    height: lineHeight / size,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    color: AppColors.ink,
    fontFeatures: _tabular,
  );

  /// 40/44 Bold. Angka utama kartu ringkasan.
  static final display = _style(40, 44, FontWeight.w700, letterSpacing: -2);

  /// 22/28 Bold. Judul layar.
  static final title = _style(22, 28, FontWeight.w700);

  /// 17/24 SemiBold. Nama kamar, judul kartu.
  static final headline = _style(17, 24, FontWeight.w600);

  /// 15/20 SemiBold. Label tombol.
  static final button = _style(15, 20, FontWeight.w600);

  /// 15/22 Medium. Teks isi.
  static final body = _style(15, 22, FontWeight.w500);

  /// 13/18 SemiBold. Chip, tombol kecil, label angka.
  static final label = _style(13, 18, FontWeight.w600);

  /// 12/16 Medium. Waktu, satuan, keterangan.
  static final caption = _style(12, 16, FontWeight.w500);

  /// Satuan di samping angka (L, L/menit): lebih kecil, 600, ink-muted.
  static final unit = label.copyWith(color: AppColors.inkMuted);
}
