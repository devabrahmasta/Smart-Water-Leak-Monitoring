import 'package:flutter/material.dart';

import '../../components/components.dart';
import '../../core/format/formatters.dart';
import '../../core/presentation/labels.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/models.dart';

/// Sheet detail alert (US-11): aturan yang terpicu, kamar, waktu, status.
/// [onOpenValve] diisi di R-12 untuk LEAK yang valve-nya tertutup.
Future<void> showAlertDetailSheet(
  BuildContext context, {
  required Alert alert,
  required VoidCallback onViewRoom,
  VoidCallback? onOpenValve,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: AppColors.ink.withValues(alpha: 0.4),
    builder: (sheetContext) => SafeArea(
      minimum: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.xxl,
      ),
      child: _AlertDetail(
        alert: alert,
        onViewRoom: () {
          Navigator.of(sheetContext).pop();
          onViewRoom();
        },
        onOpenValve: onOpenValve == null
            ? null
            : () {
                Navigator.of(sheetContext).pop();
                onOpenValve();
              },
      ),
    ),
  );
}

class _AlertDetail extends StatelessWidget {
  const _AlertDetail({
    required this.alert,
    required this.onViewRoom,
    required this.onOpenValve,
  });

  final Alert alert;
  final VoidCallback onViewRoom;
  final VoidCallback? onOpenValve;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Kamar', alert.roomName),
      ('Aturan', ruleLabel(alert)),
      if (alert.detail['flow_lpm'] is num)
        ('Debit saat terpicu', formatFlow(alert.detail['flow_lpm'] as num)),
      if (alert.detail['ratio'] is num)
        ('Dibanding rata rata', formatRatio(alert.detail['ratio'] as num)),
      ('Waktu', formatWhen(alert.createdAt)),
      (
        'Status',
        switch (alert.status) {
          AlertStatus.open => 'Aktif',
          AlertStatus.resolved =>
            'Selesai${alert.resolvedAt != null ? ' · ${formatWhen(alert.resolvedAt!)}' : ''}',
          AlertStatus.info => 'Info',
        },
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: AppRadius.cardAll,
        boxShadow: AppShadows.float,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: const BoxDecoration(
                color: AppColors.surfaceStrong,
                borderRadius: AppRadius.pillAll,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            header: true,
            child: Text(alertTitle(alert), style: AppTextStyles.headline),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(
                      label,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ),
                  Expanded(child: Text(value, style: AppTextStyles.body)),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Lihat kamar',
                  style: AppButtonStyle.secondary,
                  expand: true,
                  onPressed: onViewRoom,
                ),
              ),
              if (onOpenValve != null) ...[
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppButton(
                    label: 'Buka valve',
                    expand: true,
                    onPressed: onOpenValve,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
