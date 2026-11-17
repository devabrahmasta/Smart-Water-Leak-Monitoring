import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../core/network/api_exception.dart';
import '../../core/presentation/screen_body.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/models.dart';
import '../../data/providers/providers.dart';

/// Mode demo: mengatur simulator Kamar 3 lewat backend, jadi alurnya sama
/// dengan kebocoran sungguhan. Kamar 1 dan Kamar 2 memakai alat asli dan
/// tidak terpengaruh.
class DemoPage extends ConsumerWidget {
  const DemoPage({super.key});

  /// Kamar 3 adalah simulator Mode demo.
  static const _simulatedRoomId = 3;

  static const _options = <(DemoScenarioKind, String, String)>[
    (DemoScenarioKind.normal, 'Normal', 'Pemakaian air seperti biasa'),
    (
      DemoScenarioKind.leakStable,
      'Bocor: aliran stabil',
      'Langsung bocor, air dihentikan otomatis',
    ),
    (
      DemoScenarioKind.leakContinuous,
      'Bocor: air mengalir terus',
      'Langsung bocor, air dihentikan otomatis',
    ),
    (
      DemoScenarioKind.leakQuietHours,
      'Bocor: jam sepi',
      'Langsung bocor, air dihentikan otomatis',
    ),
    (
      DemoScenarioKind.offline,
      'Offline',
      'Alat berhenti mengirim data, Offline dalam ±40 detik',
    ),
    (
      DemoScenarioKind.noAck,
      'Alat tidak merespons',
      'Saklar gagal setelah 15 detik',
    ),
  ];

  Future<bool> _select(
    BuildContext context,
    WidgetRef ref,
    DemoScenarioKind scenario,
  ) async {
    try {
      await ref
          .read(repositoryProvider)
          .setDemoScenario(_simulatedRoomId, scenario);
      ref.read(selectedDemoScenarioProvider.notifier).set(scenario);
      refreshAll(ref);
      return true;
    } on ApiException catch (e) {
      if (context.mounted) {
        showToast(context, type: ToastType.error, message: e.message);
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(selectedDemoScenarioProvider);

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
          'Hanya mengatur Kamar 3, yang memakai simulator. Kamar 1 dan '
          'Kamar 2 selalu memakai data asli dari alat.',
          style: AppTextStyles.body.copyWith(color: AppColors.inkMuted),
        ),
        const SectionTitle('Keadaan Kamar 3'),
        for (final (scenario, title, subtitle) in _options) ...[
          AppButton(
            label: title,
            style: current == scenario
                ? AppButtonStyle.primary
                : AppButtonStyle.secondary,
            expand: true,
            icon: current == scenario ? AppIcons.check : null,
            onPressed: () => _select(context, ref, scenario),
          ),
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.xs,
              bottom: AppSpacing.md,
              left: AppSpacing.lg,
            ),
            child: Text(
              subtitle,
              style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted),
            ),
          ),
        ],
      ],
    );
  }
}
