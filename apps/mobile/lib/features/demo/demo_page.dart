import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../core/config/env.dart';
import '../../core/presentation/screen_body.dart';
import '../../core/push/push_service.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/mock/mock_smart_water_repository.dart';
import '../../data/providers/providers.dart';

/// Mode demo untuk presentasi: pilih keadaan kamar tanpa menunggu perangkat
/// (45 menit bocor, jam 01.00 sampai 04.00), lalu coba notifikasi kebocoran.
class DemoPage extends ConsumerWidget {
  const DemoPage({super.key});

  /// Alert bocor Kamar 2 di data mock skenario Bocor.
  static const _mockLeakAlertId = 31;

  static const _options = <(MockScenario?, String, String)>[
    (null, '', ''),
    (
      MockScenario.allNormal,
      'Semua normal',
      'Semua kamar memakai air seperti biasa',
    ),
    (
      MockScenario.standard,
      'Kamar 2 bocor',
      'Air dihentikan otomatis, ada alert aktif',
    ),
    (MockScenario.offline, 'Kamar 2 offline', 'Alat tidak mengirim data'),
    (
      MockScenario.noAck,
      'Alat tidak merespons',
      'Saklar valve gagal setelah 15 detik',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(demoScenarioProvider);
    final defaultLabel = Env.useMock
        ? 'Data contoh bawaan'
        : 'Data asli dari alat';

    return ScreenBody(
      onRefresh: () async => refreshAll(ref),
      children: [
        ScreenHeader.sub(
          title: 'Mode demo',
          onBack: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.home),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Untuk presentasi. Pilih keadaan kamar supaya tidak perlu menunggu '
          'kebocoran sungguhan. Data asli tidak berubah.',
          style: AppTextStyles.body.copyWith(color: AppColors.inkMuted),
        ),
        const SectionTitle('Keadaan kamar'),
        for (final (scenario, title, subtitle) in _options) ...[
          AppButton(
            label: scenario == null ? defaultLabel : title,
            style: current == scenario
                ? AppButtonStyle.primary
                : AppButtonStyle.secondary,
            expand: true,
            icon: current == scenario ? AppIcons.check : null,
            onPressed: () {
              ref.read(demoScenarioProvider.notifier).set(scenario);
              refreshAll(ref);
            },
          ),
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.xs,
              bottom: AppSpacing.md,
              left: AppSpacing.lg,
            ),
            child: Text(
              scenario == null
                  ? (Env.useMock
                        ? 'Data contoh dari kontrak'
                        : 'Data dari backend dan alat di kamar')
                  : subtitle,
              style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted),
            ),
          ),
        ],
        const SectionTitle('Coba notifikasi'),
        Text(
          'Ketuk tombol, lalu keluar dari aplikasi. Lima detik kemudian '
          'notifikasi kebocoran Kamar 2 masuk. Ketuk notifikasinya untuk '
          'membuka Detail Kamar 2.',
          style: AppTextStyles.body.copyWith(color: AppColors.inkMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Kirim notifikasi bocor',
          style: AppButtonStyle.danger,
          expand: true,
          onPressed: () async {
            // Data ikut bocor supaya Detail Kamar berisi penjelasan kebocoran.
            ref.read(demoScenarioProvider.notifier).set(MockScenario.standard);
            refreshAll(ref);
            final enabled = await requestNotificationPermission();
            if (!context.mounted) return;
            showToast(
              context,
              type: enabled ? ToastType.success : ToastType.error,
              message: enabled
                  ? 'Notifikasi masuk 5 detik lagi'
                  : 'Notifikasi mati. Aktifkan di Pengaturan',
            );
            if (enabled) {
              await showDemoLeakNotification(
                alertId: _mockLeakAlertId,
                roomId: 2,
                roomName: 'Kamar 2',
              );
            }
          },
        ),
      ],
    );
  }
}
