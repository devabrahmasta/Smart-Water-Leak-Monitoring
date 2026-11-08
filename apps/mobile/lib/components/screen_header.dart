import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_tokens.dart';
import 'app_icon_button.dart';

/// Figma: Components / Screen Header.
/// - [ScreenHeader.home]: sapaan + keterangan + lonceng.
/// - [ScreenHeader.title]: judul layar tab (Kamar, Notifikasi).
/// - [ScreenHeader.sub]: tombol kembali + judul.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader.home({
    super.key,
    required this.title,
    required String this.subtitle,
    required VoidCallback this.onBell,
    this.bellBadge = false,
    this.onDemo,
  }) : onBack = null;

  const ScreenHeader.title({super.key, required this.title, this.subtitle})
    : onBell = null,
      onDemo = null,
      bellBadge = false,
      onBack = null;

  const ScreenHeader.sub({
    super.key,
    required this.title,
    required VoidCallback this.onBack,
  }) : subtitle = null,
       onBell = null,
       onDemo = null,
       bellBadge = false;

  final String title;
  final String? subtitle;
  final VoidCallback? onBell;
  final bool bellBadge;
  final VoidCallback? onBack;

  /// Tombol Mode demo di samping lonceng (Beranda).
  final VoidCallback? onDemo;

  @override
  Widget build(BuildContext context) {
    if (onBack != null) {
      return SizedBox(
        height: 44,
        child: Row(
          children: [
            AppIconButton(
              icon: AppIcons.back,
              onPressed: onBack,
              semanticLabel: 'Kembali',
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headline,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.title,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
              ],
            ),
          ),
          if (onDemo != null) ...[
            const SizedBox(width: AppSpacing.md),
            AppIconButton(
              icon: AppIcons.demo,
              onPressed: onDemo,
              background: AppColors.bg,
              semanticLabel: 'Mode demo',
            ),
          ],
          if (onBell != null) ...[
            const SizedBox(width: AppSpacing.md),
            AppIconButton(
              icon: AppIcons.bell,
              onPressed: onBell,
              badge: bellBadge,
              background: AppColors.bg,
              semanticLabel: bellBadge
                  ? 'Notifikasi, ada alert aktif'
                  : 'Notifikasi',
            ),
          ],
        ],
      ),
    );
  }
}
