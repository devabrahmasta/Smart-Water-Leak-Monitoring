import 'package:flutter/painting.dart';

/// Token warna dari `docs/DESIGN.md` bagian 2 (Figma page Foundations).
/// Jangan menulis warna lain di luar kelas ini.
abstract final class AppColors {
  // Permukaan
  static const bg = Color(0xFFFFFCF6);
  static const surface = Color(0xFFF2F0EA);
  static const surfaceStrong = Color(0xFFE7E4DC);

  // Teks
  static const ink = Color(0xFF16181C);
  static const inkMuted = Color(0xFF5F625F);
  static const inkSubtle = Color(0xFF9B9C97);
  static const onDark = Color(0xFFFFFCF6);

  // Primary
  static const primary = Color(0xFF3389F1);
  static const primaryPress = Color(0xFF2A78D6);
  static const primarySoft = Color(0xFFDDEBFC);
  static const primaryText = Color(0xFF1E5FB0);
  static const onPrimary = Color(0xFFFFFFFF);

  // Bocor (satu-satunya warna semantik tambahan)
  static const danger = Color(0xFFD2392F);
  static const dangerSoft = Color(0xFFFBE4E1);
  static const dangerText = Color(0xFFB02A22);
}
