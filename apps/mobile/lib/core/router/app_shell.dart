import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/bottom_nav.dart';
import '../../data/providers/providers.dart';
import '../theme/app_tokens.dart';

/// Kerangka 3 tab: konten tab di belakang, Bottom Nav melayang di bawah.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Ruang bawah yang harus disisakan konten scroll supaya tidak tertutup nav.
  static const double contentBottomInset =
      BottomNav.height + AppSpacing.xxl + AppSpacing.xxl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: navigationShell),
          Positioned(
            left: AppSpacing.gutter,
            right: AppSpacing.gutter,
            bottom: 0,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: AppSpacing.xxl),
              child: BottomNav(
                currentIndex: navigationShell.currentIndex,
                // Badge = jumlah alert OPEN (US-11).
                badgeIndex: 2,
                badgeCount: ref.watch(openAlertCountProvider),
                onTap: (index) => navigationShell.goBranch(
                  index,
                  // Tap tab yang sedang aktif kembali ke akar tab itu.
                  initialLocation: index == navigationShell.currentIndex,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
