import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../core/format/formatters.dart';
import '../../core/presentation/screen_body.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/models.dart';
import '../../data/providers/providers.dart';

/// `2026-11-13` untuk hari WIB [day].
String wibDateKey(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

/// Grafik aliran L/menit: per jam dalam sehari, diketuk untuk per menit dalam
/// satu jam. Debit sekarang diperbarui tiap 1 detik.
class FlowPage extends ConsumerStatefulWidget {
  const FlowPage({super.key, required this.roomId});

  final int roomId;

  @override
  ConsumerState<FlowPage> createState() => _FlowPageState();
}

class _FlowPageState extends ConsumerState<FlowPage> {
  late DateTime _day = _today;
  int? _hour;

  static DateTime get _today {
    final now = toWib(DateTime.now());
    return DateTime(now.year, now.month, now.day);
  }

  bool get _isToday => _day == _today;

  String get _dayLabel => _isToday
      ? 'Hari ini'
      : formatShortDate(DateTime.utc(_day.year, _day.month, _day.day, 5));

  void _shiftDay(int days) => setState(() {
    _day = DateTime(_day.year, _day.month, _day.day + days);
    _hour = null;
  });

  String _clock(int hour, [int minute = 0]) =>
      '${hour.toString().padLeft(2, '0')}.${minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final query = (roomId: widget.roomId, date: wibDateKey(_day), hour: _hour);
    final series = ref.watch(flowSeriesProvider(query));
    final live = ref.watch(liveFlowProvider(widget.roomId)).value;
    final name = ref.watch(roomDetailProvider(widget.roomId)).value?.room.name;
    final parent = GoRouterState.of(context).uri.path.replaceAll('/aliran', '');

    return ScreenBody(
      onRefresh: () => refreshProvider(ref, flowSeriesProvider(query).future),
      children: [
        ScreenHeader.sub(
          title: 'Aliran ${name ?? 'kamar'}',
          onBack: () => context.canPop() ? context.pop() : context.go(parent),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          'Aliran sekarang',
          style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted),
        ),
        Text(
          live?.flowLpm == null ? 'Tidak ada data' : formatFlow(live!.flowLpm!),
          style: AppTextStyles.title,
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            AppIconButton(
              icon: AppIcons.back,
              semanticLabel: 'Hari sebelumnya',
              onPressed: () => _shiftDay(-1),
            ),
            Expanded(
              child: Text(
                _dayLabel,
                textAlign: TextAlign.center,
                style: AppTextStyles.label,
              ),
            ),
            AppIconButton(
              icon: AppIcons.forward,
              semanticLabel: 'Hari berikutnya',
              onPressed: _isToday ? null : () => _shiftDay(1),
            ),
          ],
        ),
        cardGap,
        if (_hour != null) ...[
          AppButton(
            label: 'Kembali ke per jam',
            style: AppButtonStyle.secondary,
            size: AppButtonSize.medium,
            icon: AppIcons.back,
            onPressed: () => setState(() => _hour = null),
          ),
          cardGap,
        ],
        AsyncView<FlowSeries>(
          value: series,
          onRetry: () => ref.invalidate(flowSeriesProvider(query)),
          builder: (s) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UsageChartCard(
                title: _hour == null
                    ? 'Rata-rata per jam'
                    : 'Rata-rata per menit',
                rangeLabel: _hour == null
                    ? '00.00 sampai 24.00'
                    : '${_clock(_hour!)} sampai ${_clock(_hour! + 1)}',
                points: [
                  for (final p in s.points)
                    ChartPoint(label: p.label, liters: p.avgLpm),
                ],
                formatValue: formatFlow,
                emptyText: 'Belum ada aliran',
                labelEvery: _hour == null ? 6 : 15,
                onBarTap: _hour == null
                    ? (i) => setState(() => _hour = i)
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _summary(s),
                style: AppTextStyles.body.copyWith(color: AppColors.inkMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _summary(FlowSeries s) {
    FlowPoint? top;
    for (final p in s.points) {
      if (p.maxLpm > 0 && (top == null || p.maxLpm > top.maxLpm)) top = p;
    }
    final hint = _hour == null
        ? ' Ketuk satu jam untuk melihat per menit.'
        : '';
    if (top == null) return 'Tidak ada aliran pada rentang ini.$hint';
    final at = _hour == null
        ? 'jam ${top.label}.00'
        : 'pukul ${_clock(_hour!, int.parse(top.label))}';
    return 'Tertinggi ${formatFlow(top.maxLpm)} pada $at.$hint';
  }
}
