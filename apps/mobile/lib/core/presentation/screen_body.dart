import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Refreshable;

import '../../components/components.dart';
import '../router/app_shell.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_tokens.dart';

/// Kerangka isi layar: gutter 20, ruang bawah untuk nav melayang,
/// tarik untuk muat ulang.
class ScreenBody extends StatelessWidget {
  const ScreenBody({
    super.key,
    required this.children,
    required this.onRefresh,
    this.background,
  });

  final List<Widget> children;
  final Future<void> Function() onRefresh;

  /// Lapisan di belakang konten (gradien Beranda).
  final Widget? background;

  @override
  Widget build(BuildContext context) {
    final list = RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.bg,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          MediaQuery.paddingOf(context).top + AppSpacing.xxl,
          AppSpacing.gutter,
          AppShell.contentBottomInset,
        ),
        children: children,
      ),
    );
    if (background == null) return list;
    return Stack(children: [background!, list]);
  }
}

/// Judul seksi ("Perlu dicek", "Riwayat perintah") dengan jarak antar seksi.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(
      top: AppSpacing.sectionGap,
      bottom: AppSpacing.md,
    ),
    child: Semantics(
      header: true,
      child: Text(text, style: AppTextStyles.headline),
    ),
  );
}

/// Jarak antar kartu.
const cardGap = SizedBox(height: AppSpacing.cardGap);

/// Menampilkan [AsyncValue]:
/// - memuat pertama kali: indikator kecil;
/// - gagal tanpa data: kartu galat yang bisa diketuk untuk coba lagi;
/// - gagal setelah pernah berhasil: data lama tetap tampil + baris
///   "Gagal memperbarui · Coba lagi" (US-19).
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.onRetry,
    required this.builder,
    this.showStaleBanner = true,
  });

  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(T data) builder;
  final bool showStaleBanner;

  @override
  Widget build(BuildContext context) {
    if (value.hasValue) {
      final content = builder(value.requireValue);
      if (!value.hasError || !showStaleBanner) return content;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StaleDataBanner(onRetry: onRetry),
          const SizedBox(height: AppSpacing.md),
          content,
        ],
      );
    }
    if (value.hasError) {
      return GestureDetector(
        onTap: onRetry,
        child: const EmptyState(
          icon: AppIcons.offline,
          title: 'Gagal memuat data',
          message: 'Ketuk untuk coba lagi',
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
      child: Center(
        child: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            strokeCap: StrokeCap.round,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

/// Baris "Gagal memperbarui · Coba lagi" di atas konten (US-19).
class StaleDataBanner extends StatelessWidget {
  const StaleDataBanner({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      button: true,
      label: 'Gagal memperbarui. Coba lagi',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onRetry,
        child: SizedBox(
          height: AppSizes.minTouch,
          child: Row(
            children: [
              const Icon(
                AppIcons.offline,
                size: 16,
                color: AppColors.dangerText,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Gagal memperbarui · ',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.dangerText,
                ),
              ),
              Text(
                'Coba lagi',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.primaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tunggu provider dimuat ulang (dipakai RefreshIndicator).
Future<void> refreshProvider<T>(
  WidgetRef ref,
  Refreshable<Future<T>> provider,
) async {
  try {
    final _ = await ref.refresh(provider);
  } catch (_) {
    // Galat sudah ditampilkan oleh AsyncView.
  }
}
