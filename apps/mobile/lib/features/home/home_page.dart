import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../core/config/env.dart';
import '../../core/format/formatters.dart';
import '../../core/presentation/labels.dart';
import '../../core/presentation/screen_body.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/models.dart';
import '../../data/providers/providers.dart';
import '../alerts/alert_detail_sheet.dart';
import '../rooms/room_card_view.dart';

/// Beranda (US-01, US-02, US-03, US-18).
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(summaryProvider);
    final rooms = ref.watch(roomsProvider);
    final openCount = ref.watch(openAlertCountProvider);

    return ScreenBody(
      background: Container(
        height: AppGradients.homeHeaderHeight,
        decoration: BoxDecoration(gradient: AppGradients.homeHeader),
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
        ),
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
                ? 'Valve ditutup otomatis · ${formatClock(latest.createdAt)}'
                : '${latest.roomName} · ${formatClock(latest.createdAt)}',
            onView: () => openAlertSheet(context, ref, latest.id),
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

/// Ambil alert terbaru lalu buka sheet detailnya.
Future<void> openAlertSheet(BuildContext context, WidgetRef ref, int id) async {
  final repo = ref.read(repositoryProvider);
  try {
    final alert = await repo.getAlert(id);
    if (!context.mounted) return;
    await showAlertDetailSheet(
      context,
      alert: alert,
      onViewRoom: () => context.go(AppRoutes.homeRoom(alert.roomId)),
    );
  } catch (_) {
    if (context.mounted) {
      showToast(
        context,
        type: ToastType.error,
        message: 'Gagal memuat detail. Coba lagi',
      );
    }
  }
}
