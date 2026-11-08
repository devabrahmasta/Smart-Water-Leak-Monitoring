import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../core/config/env.dart';
import '../../core/format/formatters.dart';
import '../../core/presentation/labels.dart';
import '../../core/push/push_service.dart';
import '../../core/presentation/screen_body.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/models.dart';
import '../../data/providers/providers.dart';
import '../alerts/alert_actions.dart';
import '../rooms/room_card_view.dart';

/// Beranda (US-01, US-02, US-03, US-18).
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(summaryProvider);
    final rooms = ref.watch(roomsProvider);
    final openCount = ref.watch(openAlertCountProvider);
    final leak = ref.watch(activeLeakProvider);

    return ScreenBody(
      background: Container(
        height: AppGradients.homeHeaderHeight,
        decoration: BoxDecoration(
          gradient: leak ? AppGradients.leakHeader : AppGradients.homeHeader,
        ),
      ),
      onRefresh: () async {
        ref.invalidate(roomsProvider);
        await refreshProvider(ref, summaryProvider.future);
      },
      children: [
        ScreenHeader.home(
          title: 'Halo, ${Env.ownerName}',
          subtitle: '${Env.propertyName} · ${formatDayDate(DateTime.now())}',
          bellBadge: openCount > 0,
          onBell: () => context.go(AppRoutes.alerts),
          onDemo: () => context.go(AppRoutes.demo),
        ),
        const _NotificationOffBanner(),
        const SizedBox(height: AppSpacing.xxl),
        AsyncView<Summary>(
          value: summary,
          onRetry: () => ref.invalidate(summaryProvider),
          builder: (s) => _SummaryGroup(summary: s),
        ),
        const SectionTitle('Perlu dicek'),
        AsyncView<List<Room>>(
          value: rooms,
          onRetry: () => ref.invalidate(roomsProvider),
          showStaleBanner: false,
          builder: (list) => _AttentionList(rooms: list),
        ),
        if (kDebugMode) ...[
          const SizedBox(height: AppSpacing.sectionGap),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: 'Galeri komponen',
              style: AppButtonStyle.secondary,
              size: AppButtonSize.medium,
              onPressed: () => context.push(AppRoutes.gallery),
            ),
          ),
        ],
      ],
    );
  }
}

class _SummaryGroup extends ConsumerWidget {
  const _SummaryGroup({required this.summary});

  final Summary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = summary.latestOpenAlert;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SummaryCard(
          todayLiters: summary.todayL,
          monthLiters: summary.monthL,
          last7DaysLiters: summary.last7DaysL,
          leak: ref.watch(activeLeakProvider),
          onSeeChart: () => context.go(AppRoutes.usage),
        ),
        if (latest != null) ...[
          cardGap,
          AlertBanner(
            type: latest.type == AlertType.leak
                ? AlertBannerType.leak
                : AlertBannerType.anomaly,
            title: latest.type == AlertType.leak
                ? 'Kebocoran di ${latest.roomName}'
                : 'Pemakaian tidak wajar',
            subtitle: summary.openAlertCount > 1
                ? '${latest.roomName} · +${summary.openAlertCount - 1} lainnya'
                : latest.type == AlertType.leak
                ? 'Air dihentikan otomatis · ${formatClock(latest.createdAt)}'
                : '${latest.roomName} · ${formatClock(latest.createdAt)}',
            onView: () => openAlertById(
              context,
              ref,
              alertId: latest.id,
              roomRoute: AppRoutes.homeRoom,
            ),
          ),
        ],
        cardGap,
        StatusTally(
          normal: summary.tallyNormal,
          closed: summary.tallyClosed,
          offline: summary.tallyOffline,
        ),
      ],
    );
  }
}

class _AttentionList extends StatelessWidget {
  const _AttentionList({required this.rooms});

  final List<Room> rooms;

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty) {
      return const EmptyState(
        icon: AppIcons.room,
        title: 'Belum ada kamar terhubung',
        message: 'Kamar muncul setelah perangkat mengirim data',
      );
    }
    final attention = roomsNeedingAttention(rooms);
    if (attention.isEmpty) {
      return const EmptyState(
        title: 'Semua kamar normal',
        message: 'Tidak ada kebocoran atau perangkat offline',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < attention.length; i++) ...[
          if (i > 0) cardGap,
          RoomCardView(
            room: attention[i],
            onTap: () => context.go(AppRoutes.homeRoom(attention[i].id)),
          ),
        ],
      ],
    );
  }
}

/// "Notifikasi mati. Aktifkan di Pengaturan" bila izin ditolak (US-20).
class _NotificationOffBanner extends ConsumerWidget {
  const _NotificationOffBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(notificationsEnabledProvider).value ?? true;
    final dismissed = ref.watch(notificationBannerDismissedProvider);
    if (enabled || dismissed) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Row(
        children: [
          const Icon(AppIcons.bell, size: 16, color: AppColors.inkMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                await requestNotificationPermission();
                ref.invalidate(notificationsEnabledProvider);
              },
              child: Text(
                'Notifikasi mati. Aktifkan di Pengaturan',
                style: AppTextStyles.label.copyWith(color: AppColors.inkMuted),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: 'Tutup pengingat notifikasi',
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => ref
                  .read(notificationBannerDismissedProvider.notifier)
                  .dismiss(),
              child: const SizedBox.square(
                dimension: AppSizes.minTouch,
                child: Icon(
                  AppIcons.close,
                  size: 16,
                  color: AppColors.inkMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
