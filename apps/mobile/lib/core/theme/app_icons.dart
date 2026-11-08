import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Ikon Lucide yang ada di Figma page Icons. Layar dan komponen hanya
/// memakai ikon dari sini, supaya ganti set ikon cukup di satu file.
abstract final class AppIcons {
  static const IconData home = LucideIcons.house;
  static const IconData chart = LucideIcons.chartColumn;
  static const IconData bell = LucideIcons.bell;
  static const IconData alert = LucideIcons.triangleAlert;
  static const IconData offline = LucideIcons.wifiOff;
  static const IconData back = LucideIcons.chevronLeft;
  static const IconData forward = LucideIcons.chevronRight;
  static const IconData check = LucideIcons.check;
  static const IconData close = LucideIcons.x;
  static const IconData lock = LucideIcons.lock;
  static const IconData anomaly = LucideIcons.activity;
  static const IconData success = LucideIcons.circleCheck;
  static const IconData auto = LucideIcons.zap;
  static const IconData app = LucideIcons.smartphone;
  static const IconData manualButton = LucideIcons.hand;
  static const IconData highest = LucideIcons.trendingUp;
  static const IconData clock = LucideIcons.clock;
  static const IconData water = LucideIcons.droplet;
  static const IconData room = LucideIcons.doorClosed;
  static const IconData demo = LucideIcons.flaskConical;
}
