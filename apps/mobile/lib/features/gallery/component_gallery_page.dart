import 'package:flutter/material.dart';

import '../../components/components.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_tokens.dart';

/// Galeri internal R-10: semua komponen dan variannya, untuk dibandingkan
/// dengan Figma page Components. Hanya bisa dibuka di build debug.
class ComponentGalleryPage extends StatefulWidget {
  const ComponentGalleryPage({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<ComponentGalleryPage> createState() => _ComponentGalleryPageState();
}

class _ComponentGalleryPageState extends State<ComponentGalleryPage> {
  String _period = 'daily';
  String _room = 'all';
  bool _valveOn = true;

  static const _daily = [
    ChartPoint(label: '1', liters: 610),
    ChartPoint(label: '2', liters: 690),
    ChartPoint(label: '3', liters: 660),
    ChartPoint(label: '4', liters: 1004),
    ChartPoint(label: '5', liters: 720),
    ChartPoint(label: '6', liters: 120),
  ];

  static const _monthly = [
    ChartPoint(label: 'Jun', liters: 17800),
    ChartPoint(label: 'Jul', liters: 18900),
    ChartPoint(label: 'Agu', liters: 20100),
    ChartPoint(label: 'Sep', liters: 18400),
    ChartPoint(label: 'Okt', liters: 24610),
    ChartPoint(label: 'Nov', liters: 3100),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.lg,
            AppSpacing.gutter,
            AppSpacing.xxxl,
          ),
          children: [
            ScreenHeader.sub(
              title: 'Galeri komponen',
              onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
            ),
            _section('Button', [
              for (final style in AppButtonStyle.values)
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    AppButton(
                      label: 'Buka valve',
                      style: style,
                      onPressed: () {},
                    ),
                    AppButton(
                      label: 'Buka valve',
                      style: style,
                      onPressed: null,
                    ),
                    AppButton(
                      label: 'Buka valve',
                      style: style,
                      loading: true,
                      onPressed: () {},
                    ),
                    AppButton(
                      label: 'Buka valve',
                      style: style,
                      size: AppButtonSize.medium,
                      onPressed: () {},
                    ),
                  ],
                ),
            ]),
            _section('Valve Switch', [
              Wrap(
                spacing: AppSpacing.md,
                children: [
                  ValveSwitch(
                    state: _valveOn
                        ? ValveSwitchState.on
                        : ValveSwitchState.off,
                    onChanged: (v) => setState(() => _valveOn = v),
                  ),
                  const ValveSwitch(state: ValveSwitchState.off),
                  const ValveSwitch(state: ValveSwitchState.pending),
                  const ValveSwitch(state: ValveSwitchState.disabled),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    decoration: const BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: AppRadius.pillAll,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ValveSwitch(state: ValveSwitchState.on, dark: true),
                        SizedBox(width: AppSpacing.sm),
                        ValveSwitch(state: ValveSwitchState.off, dark: true),
                      ],
                    ),
                  ),
                ],
              ),
            ]),
            _section('Status Chip', [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final t in StatusChipType.values) StatusChip(t),
                  const StatusTag(label: 'Aktif', tone: TagTone.danger),
                  const StatusTag(label: 'Aktif', tone: TagTone.primary),
                  const StatusTag(label: 'Selesai', tone: TagTone.neutral),
                ],
              ),
            ]),
            _section('Icon Button', [
              Row(
                children: [
                  AppIconButton(
                    icon: AppIcons.bell,
                    onPressed: () {},
                    semanticLabel: 'Notifikasi',
                  ),
                  const SizedBox(width: AppSpacing.md),
                  AppIconButton(
                    icon: AppIcons.bell,
                    badge: true,
                    onPressed: () {},
                    semanticLabel: 'Notifikasi',
                  ),
                ],
              ),
            ]),
            _section('Segmented Control', [
              Align(
                alignment: Alignment.centerLeft,
                child: SegmentedControl<String>(
                  segments: const [('daily', 'Harian'), ('monthly', 'Bulanan')],
                  selected: _period,
                  onChanged: (v) => setState(() => _period = v),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: SegmentedControl<String>(
                  segments: const [
                    ('all', 'Semua'),
                    ('attention', 'Perlu dicek'),
                    ('offline', 'Offline'),
                  ],
                  selected: _room,
                  onChanged: (v) => setState(() => _room = v),
                ),
              ),
            ]),
            _section('Screen Header', [
              ScreenHeader.home(
                title: 'Halo, Pak Hendra',
                subtitle: 'Kos Melati · Jumat, 6 November',
                bellBadge: true,
                onBell: () {},
              ),
              const ScreenHeader.title(title: 'Kamar'),
              ScreenHeader.sub(title: 'Kamar 1', onBack: () {}),
            ]),
            _section('Summary Card', [
              SummaryCard(
                todayLiters: 230,
                monthLiters: 4812,
                last7DaysLiters: const [210, 198, 240, 305, 188, 276, 30],
                onSeeChart: () {},
              ),
            ]),
            _section('Status Tally', [
              const StatusTally(normal: 1, closed: 1, offline: 0),
            ]),
            _section('Alert Banner', [
              AlertBanner(
                type: AlertBannerType.leak,
                title: 'Kebocoran di Kamar 2',
                subtitle: 'Valve ditutup otomatis · 02.14',
                onView: () {},
              ),
              AlertBanner(
                type: AlertBannerType.anomaly,
                title: 'Pemakaian tidak wajar',
                subtitle: 'Kamar 1 · 1,7× rata rata harian',
                onView: () {},
              ),
            ]),
            _section('Metric Tile', [
              const Row(
                children: [
                  Expanded(
                    child: MetricTile(label: 'Total November', value: '4.812'),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: MetricTile(label: 'Rata rata harian', value: null),
                  ),
                ],
              ),
            ]),
            _section('Room Card', [
              RoomCard(
                name: 'Kamar 1',
                status: RoomCardStatus.normal,
                todayLiters: 142,
                flowLpm: 6.4,
                isHighest: true,
                valveTitle: 'Valve terbuka',
                valveSubtitle: 'Data 10 detik lalu',
                switchState: ValveSwitchState.on,
                onValveChanged: (_) {},
                onTap: () {},
              ),
              RoomCard(
                name: 'Kamar 2',
                status: RoomCardStatus.leak,
                todayLiters: 88,
                flowLpm: 0,
                valveTitle: 'Valve tertutup otomatis',
                valveSubtitle: 'Periksa sebelum membuka',
                switchState: ValveSwitchState.off,
                onValveChanged: (_) {},
              ),
              RoomCard(
                name: 'Kamar 2',
                status: RoomCardStatus.closed,
                todayLiters: 88,
                flowLpm: 0,
                valveTitle: 'Ditutup dari aplikasi',
                valveSubtitle: '14.20 hari ini',
                switchState: ValveSwitchState.off,
                onValveChanged: (_) {},
              ),
              const RoomCard(
                name: 'Kamar 2',
                status: RoomCardStatus.offline,
                todayLiters: null,
                flowLpm: null,
                valveTitle: 'Kontrol tidak tersedia',
                valveSubtitle: 'Terakhir terlihat 01.52',
                switchState: ValveSwitchState.disabled,
              ),
              const RoomCard(
                name: 'Kamar 1',
                status: RoomCardStatus.normal,
                todayLiters: 142,
                flowLpm: 6.4,
                valveTitle: 'Menunggu perangkat',
                valveSubtitle: 'Perintah tutup dikirim',
                switchState: ValveSwitchState.pending,
              ),
            ]),
            _section('Usage Chart Card', [
              const UsageChartCard(
                title: 'Pemakaian harian',
                rangeLabel: '1 sampai 6 Nov',
                points: _daily,
              ),
              const UsageChartCard(
                title: 'Pemakaian bulanan',
                rangeLabel: 'Jun sampai Nov',
                points: _monthly,
              ),
              UsageChartCard(
                title: 'Pemakaian harian',
                rangeLabel: '1 sampai 30 Nov',
                points: [
                  for (var d = 1; d <= 30; d++)
                    ChartPoint(label: '$d', liters: 200 + (d * 37 % 140) * 3.0),
                ],
              ),
              const UsageChartCard(
                title: 'Pemakaian harian',
                rangeLabel: 'November',
                points: [],
              ),
            ]),
            _section('Room Compare', [
              const RoomCompare(
                periodLabel: 'November',
                entries: [
                  RoomCompareEntry(name: 'Kamar 2', liters: 1906),
                  RoomCompareEntry(name: 'Kamar 1', liters: 2906),
                ],
              ),
            ]),
            _section('Alert Item', [
              AlertItem(
                type: AlertItemType.leak,
                status: AlertItemStatus.open,
                title: 'Kebocoran di Kamar 2',
                subtitle: 'Aliran stabil 6 menit · Hari ini 02.14',
                onTap: () {},
              ),
              const AlertItem(
                type: AlertItemType.leak,
                status: AlertItemStatus.resolved,
                title: 'Kebocoran di Kamar 1',
                subtitle: 'Aliran jam sepi · 3 Nov 01.40',
              ),
              const AlertItem(
                type: AlertItemType.anomaly,
                status: AlertItemStatus.open,
                title: 'Pemakaian tidak wajar',
                subtitle: 'Kamar 1 · 1,7× rata rata · Kemarin 21.00',
              ),
              const AlertItem(
                type: AlertItemType.anomaly,
                status: AlertItemStatus.resolved,
                title: 'Pemakaian tidak wajar',
                subtitle: 'Kamar 2 · 1,6× rata rata · 1 Nov 22.00',
              ),
              const AlertItem(
                type: AlertItemType.activity,
                status: AlertItemStatus.info,
                title: 'Valve Kamar 2 dibuka',
                subtitle: 'Tombol fisik · Hari ini 14.20',
              ),
            ]),
            _section('Command Row', [
              for (final r in CommandResult.values)
                CommandRow(
                  action: 'Buka valve',
                  source: CommandSource.app,
                  time: '08.05',
                  result: r,
                ),
              const CommandRow(
                action: 'Tutup valve',
                source: CommandSource.auto,
                time: '02.14',
                result: CommandResult.success,
              ),
              const CommandRow(
                action: 'Buka valve',
                source: CommandSource.manualButton,
                time: '14.20',
                result: CommandResult.success,
              ),
            ]),
            _section('Confirm Sheet', [
              ConfirmSheet(
                action: ConfirmSheetAction.open,
                title: 'Buka valve Kamar 2?',
                message:
                    'Valve ditutup otomatis karena kebocoran. Buka hanya kalau penyebabnya sudah dicek.',
                confirmLabel: 'Buka valve',
                onConfirm: () {},
                onCancel: () {},
              ),
              AppButton(
                label: 'Coba sheet tutup valve',
                style: AppButtonStyle.secondary,
                size: AppButtonSize.medium,
                onPressed: () => showConfirmSheet(
                  context,
                  action: ConfirmSheetAction.close,
                  title: 'Tutup valve Kamar 1?',
                  message:
                      'Air di Kamar 1 berhenti mengalir sampai valve dibuka lagi.',
                  confirmLabel: 'Tutup valve',
                ),
              ),
            ]),
            _section('Toast', [
              const Align(
                alignment: Alignment.centerLeft,
                child: AppToast(
                  type: ToastType.success,
                  message: 'Valve Kamar 2 terbuka',
                ),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: AppToast(
                  type: ToastType.error,
                  message: 'Perangkat tidak merespons. Coba lagi',
                ),
              ),
              AppButton(
                label: 'Coba toast',
                style: AppButtonStyle.secondary,
                size: AppButtonSize.medium,
                onPressed: () => showToast(
                  context,
                  type: ToastType.success,
                  message: 'Valve Kamar 2 terbuka',
                ),
              ),
            ]),
            _section('Bottom Nav', [
              for (var i = 0; i < 3; i++)
                BottomNav(
                  currentIndex: i,
                  onTap: (_) {},
                  badgeIndex: 2,
                  badgeCount: 1,
                ),
            ]),
            _section('Empty State', [
              const EmptyState(
                title: 'Semua kamar normal',
                message: 'Tidak ada kebocoran atau perangkat offline',
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppTextStyles.headline),
          for (final child in children) ...[
            const SizedBox(height: AppSpacing.cardGap),
            child,
          ],
        ],
      ),
    );
  }
}
