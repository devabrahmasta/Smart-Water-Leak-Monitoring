import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../core/presentation/labels.dart';
import '../../core/presentation/screen_body.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/models.dart';
import '../../data/providers/providers.dart';
import 'alert_actions.dart';

enum AlertFilter { all, open, resolved }

/// Notifikasi (US-11). ACTIVITY hanya tampil di filter Semua.
class AlertsPage extends ConsumerStatefulWidget {
  const AlertsPage({super.key});

  @override
  ConsumerState<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends ConsumerState<AlertsPage> {
  AlertFilter _filter = AlertFilter.all;
  String? _handledDeepLink;

  /// Push notifikasi membuka `/notifikasi?alert=<id>` → tampilkan sheet
  /// detail alert itu sekali (CONTRACT.md 4.2).
  void _handleDeepLink() {
    final id = GoRouterState.of(context).uri.queryParameters['alert'];
    if (id == null || id == _handledDeepLink) return;
    _handledDeepLink = id;
    final alertId = int.tryParse(id);
    if (alertId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      openAlertById(
        context,
        ref,
        alertId: alertId,
        roomRoute: AppRoutes.alertRoom,
      );
    });
  }

  List<Alert> _apply(List<Alert> alerts) => switch (_filter) {
    AlertFilter.all => alerts,
    AlertFilter.open =>
      alerts.where((a) => a.status == AlertStatus.open).toList(),
    AlertFilter.resolved =>
      alerts.where((a) => a.status == AlertStatus.resolved).toList(),
  };

  @override
  Widget build(BuildContext context) {
    _handleDeepLink();
    final alerts = ref.watch(alertsProvider);

    return ScreenBody(
      onRefresh: () => refreshProvider(ref, alertsProvider.future),
      children: [
        const ScreenHeader.title(title: 'Notifikasi'),
        const SizedBox(height: AppSpacing.xxl),
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedControl<AlertFilter>(
            segments: const [
              (AlertFilter.all, 'Semua'),
              (AlertFilter.open, 'Aktif'),
              (AlertFilter.resolved, 'Selesai'),
            ],
            selected: _filter,
            onChanged: (f) => setState(() => _filter = f),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        AsyncView<List<Alert>>(
          value: alerts,
          onRetry: () => ref.invalidate(alertsProvider),
          builder: (all) {
            final list = _apply(all);
            if (list.isEmpty) {
              return EmptyState(
                title: _filter == AlertFilter.open
                    ? 'Tidak ada alert aktif'
                    : 'Belum ada notifikasi',
                message: 'Kebocoran dan pemakaian tidak wajar muncul di sini',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < list.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.sm),
                  AlertItem(
                    type: alertItemType(list[i].type),
                    status: alertItemStatus(list[i].status),
                    title: alertTitle(list[i]),
                    subtitle: alertSubtitle(list[i]),
                    onTap: () => openAlertDetail(
                      context,
                      ref,
                      alert: list[i],
                      roomRoute: AppRoutes.alertRoom(list[i].roomId),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}
