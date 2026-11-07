import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_tokens.dart';

/// Satu tab di [BottomNav].
class BottomNavItem {
  const BottomNavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Figma: Components / Bottom Nav. Pil melayang dengan 3 tab.
/// Tab aktif = pil `primary` berisi ikon + label. Tab lain ikon di atas
/// label `ink-muted`. Badge `danger` di tab Notifikasi (US-11).
class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.badgeIndex,
    this.badgeCount = 0,
    this.items = defaultItems,
  });

  static const defaultItems = [
    BottomNavItem(icon: AppIcons.home, label: 'Beranda'),
    BottomNavItem(icon: AppIcons.room, label: 'Kamar'),
    BottomNavItem(icon: AppIcons.bell, label: 'Notifikasi'),
  ];

  /// Tinggi nav (Figma 68).
  static const double height = 68;

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<BottomNavItem> items;

  /// Tab yang membawa badge. Badge disembunyikan bila 0 atau tab itu aktif.
  final int? badgeIndex;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: AppRadius.cardAll,
        boxShadow: AppShadows.float,
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.xs),
            Expanded(
              flex: i == currentIndex ? 6 : 5,
              child: _Tab(
                item: items[i],
                active: i == currentIndex,
                badge: i == badgeIndex && i != currentIndex ? badgeCount : 0,
                onTap: () => onTap(i),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.item,
    required this.active,
    required this.badge,
    required this.onTap,
  });

  final BottomNavItem item;
  final bool active;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = _BadgedIcon(
      icon: item.icon,
      color: active ? AppColors.onPrimary : AppColors.inkMuted,
      count: badge,
    );

    return Semantics(
      button: true,
      selected: active,
      label: badge > 0 ? '${item.label}, $badge aktif' : item.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppSizes.pressDuration,
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.bg,
            borderRadius: AppRadius.pillAll,
          ),
          alignment: Alignment.center,
          child: active
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    icon,
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.button.copyWith(
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    icon,
                    const SizedBox(height: 2),
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _BadgedIcon extends StatelessWidget {
  const _BadgedIcon({
    required this.icon,
    required this.color,
    required this.count,
  });

  final IconData icon;
  final Color color;
  final int count;

  @override
  Widget build(BuildContext context) {
    final glyph = Icon(icon, size: AppSizes.iconInline, color: color);
    if (count <= 0) return glyph;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        glyph,
        Positioned(
          top: -6,
          right: -8,
          child: Container(
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            decoration: const BoxDecoration(
              color: AppColors.danger,
              borderRadius: AppRadius.pillAll,
            ),
            alignment: Alignment.center,
            child: Text(
              count > 9 ? '9+' : '$count',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.onPrimary,
                fontSize: 10,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
