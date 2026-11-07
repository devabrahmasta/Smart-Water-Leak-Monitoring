import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../core/format/formatters.dart';
import '../../core/presentation/labels.dart';
import '../../core/presentation/screen_body.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/models.dart';
import '../../data/providers/providers.dart';
import '../alerts/alert_detail_sheet.dart';
import '../rooms/room_card_view.dart';

/// Detail Kamar (US-06).
class RoomDetailPage extends ConsumerWidget {
  const RoomDetailPage({super.key, required this.roomId, required this.backTo});

  final int roomId;

  /// Rute tujuan tombol kembali bila tidak ada riwayat.
  final String backTo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(roomDetailProvider(roomId));
    final usageQuery = (period: UsagePeriod.daily, roomId: roomId);
    final usage = ref.watch(usageProvider(usageQuery));
    final commands = ref.watch(roomCommandsProvider(roomId));
    final name = detail.value?.room.name ?? 'Kamar';

    return ScreenBody(
      onRefresh: () async {
        ref
          ..invalidate(usageProvider(usageQuery))
          ..invalidate(roomCommandsProvider(roomId));
        await refreshProvider(ref, roomDetailProvider(roomId).future);
      },
      children: [
        ScreenHeader.sub(
          title: name,
          onBack: () => context.canPop() ? context.pop() : context.go(backTo),
        ),
        const SizedBox(height: AppSpacing.xxl),
        AsyncView<RoomDetail>(
          value: detail,
          onRetry: () => ref.invalidate(roomDetailProvider(roomId)),
          builder: (d) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RoomCardView(room: d.room),
              cardGap,
              Row(
                children: [
                  Expanded(
                    child: MetricTile(
                      label: 'Total ${monthName(DateTime.now())}',
                      value: d.monthL == null
                          ? null
                          : formatNumber(d.monthL!.round()),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: MetricTile(
                      label: 'Rata rata harian',
                      value: d.avgDailyL == null
                          ? null
                          : formatNumber(d.avgDailyL!.round()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SectionTitle('Pemakaian'),
        AsyncView<Usage>(
          value: usage,
          showStaleBanner: false,
          onRetry: () => ref.invalidate(usageProvider(usageQuery)),
          builder: (u) => UsageChartCard(
            title: 'Pemakaian harian',
            rangeLabel: usageRangeLabel(u),
            points: chartPoints(u),
          ),
        ),
        const SectionTitle('Riwayat perintah'),
        AsyncView<List<ValveCommand>>(
          value: commands,
          showStaleBanner: false,
          onRetry: () => ref.invalidate(roomCommandsProvider(roomId)),
          builder: (list) => list.isEmpty
              ? const EmptyState(
                  title: 'Belum ada perintah',
                  message: 'Perubahan valve dari mana pun tercatat di sini',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < list.length; i++) ...[
                      if (i > 0) const SizedBox(height: AppSpacing.sm),
                      CommandRow(
                        action: commandActionLabel(list[i].action),
                        source: commandSource(list[i].source),
                        time: formatWhen(list[i].createdAt),
                        result: commandResult(list[i].status),
                      ),
                    ],
                  ],
                ),
        ),
        const SectionTitle('Alert terakhir'),
        if (detail.value case final d?)
          d.recentAlerts.isEmpty
              ? const EmptyState(
                  title: 'Belum ada alert',
                  message: 'Kebocoran dan pemakaian tidak wajar muncul di sini',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < d.recentAlerts.length; i++) ...[
                      if (i > 0) const SizedBox(height: AppSpacing.sm),
                      AlertItem(
                        type: alertItemType(d.recentAlerts[i].type),
                        status: alertItemStatus(d.recentAlerts[i].status),
                        title: alertTitle(d.recentAlerts[i]),
                        subtitle: alertSubtitle(d.recentAlerts[i]),
                        onTap: () => showAlertDetailSheet(
                          context,
                          alert: d.recentAlerts[i],
                          onViewRoom: () {},
                        ),
                      ),
                    ],
                  ],
                ),
      ],
    );
  }
}
