import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../core/format/formatters.dart';
import '../../core/presentation/labels.dart';
import '../../core/presentation/screen_body.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/models.dart';
import '../../data/providers/providers.dart';

/// Detail Grafik (US-04), dibuka dari "Lihat grafik" di Beranda.
class UsagePage extends ConsumerStatefulWidget {
  const UsagePage({super.key});

  @override
  ConsumerState<UsagePage> createState() => _UsagePageState();
}

class _UsagePageState extends ConsumerState<UsagePage> {
  UsagePeriod _period = UsagePeriod.daily;

  @override
  Widget build(BuildContext context) {
    final query = (period: _period, roomId: null);
    final usage = ref.watch(usageProvider(query));

    return ScreenBody(
      onRefresh: () => refreshProvider(ref, usageProvider(query).future),
      children: [
        ScreenHeader.sub(
          title: 'Grafik pemakaian',
          onBack: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.home),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedControl<UsagePeriod>(
            segments: const [
              (UsagePeriod.daily, 'Harian'),
              (UsagePeriod.monthly, 'Bulanan'),
            ],
            selected: _period,
            onChanged: (p) => setState(() => _period = p),
          ),
        ),
        cardGap,
        AsyncView<Usage>(
          value: usage,
          onRetry: () => ref.invalidate(usageProvider(query)),
          builder: (u) => _UsageContent(usage: u),
        ),
      ],
    );
  }
}

class _UsageContent extends StatelessWidget {
  const _UsageContent({required this.usage});

  final Usage usage;

  @override
  Widget build(BuildContext context) {
    final daily = usage.period == UsagePeriod.daily;
    final now = DateTime.now();
    final hasData = usage.series.any((p) => p.volumeL > 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UsageChartCard(
          title: daily ? 'Pemakaian harian' : 'Pemakaian bulanan',
          rangeLabel: usageRangeLabel(usage),
          points: chartPoints(usage),
        ),
        cardGap,
        Row(
          children: [
            Expanded(
              child: MetricTile(
                label: daily ? 'Total ${monthName(now)}' : 'Total 6 bulan',
                value: hasData ? formatNumber(usage.totalL.round()) : null,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: MetricTile(
                label: daily ? 'Rata rata mingguan' : 'Rata rata bulanan',
                // Mode harian: rata rata harian × 7.
                value: hasData
                    ? formatNumber(
                        (daily ? usage.averageL * 7 : usage.averageL).round(),
                      )
                    : null,
              ),
            ),
          ],
        ),
        const SectionTitle('Per kamar'),
        RoomCompare(
          periodLabel: daily ? monthName(now) : '6 bulan terakhir',
          entries: [
            for (final r in usage.byRoom)
              RoomCompareEntry(name: r.name, liters: r.volumeL),
          ],
        ),
      ],
    );
  }
}
