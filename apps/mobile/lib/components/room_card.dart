import 'package:flutter/material.dart';

import '../core/format/formatters.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_tokens.dart';
import 'card_parts.dart';
import 'status_chip.dart';
import 'valve_switch.dart';

/// Status kamar sesuai enum kontrak (CONTRACT.md 3: NORMAL, LEAK, CLOSED,
/// OFFLINE).
enum RoomCardStatus { normal, leak, closed, offline }

/// Figma: Components / Room Card (US-05, US-07, US-09).
///
/// Aturan status (DESIGN.md 6):
/// - normal: kartu `surface`, chip Normal.
/// - leak: kartu `surface`, chip Bocor, valve otomatis off.
/// - closed: kartu `ink` (satu-satunya kartu gelap), teks `on-dark`.
/// - offline: angka diganti "Tidak ada data", saklar disabled.
///
/// Teks panel valve ([valveTitle], [valveSubtitle]) disusun layar karena
/// bergantung data (sumber penutupan, umur data, waktu terakhir terlihat).
class RoomCard extends StatelessWidget {
  const RoomCard({
    super.key,
    required this.name,
    required this.status,
    required this.todayLiters,
    required this.flowLpm,
    required this.valveTitle,
    required this.valveSubtitle,
    required this.switchState,
    this.isHighest = false,
    this.onValveChanged,
    this.onTap,
  });

  final String name;
  final RoomCardStatus status;

  /// Null saat offline.
  final double? todayLiters;
  final double? flowLpm;

  final String valveTitle;
  final String valveSubtitle;
  final ValveSwitchState switchState;
  final bool isHighest;
  final ValueChanged<bool>? onValveChanged;
  final VoidCallback? onTap;

  bool get _dark => status == RoomCardStatus.closed;

  @override
  Widget build(BuildContext context) {
    final fg = _dark ? AppColors.onDark : AppColors.ink;
    final muted = _dark
        ? AppColors.onDark.withValues(alpha: 0.7)
        : AppColors.inkMuted;
    final offline = status == RoomCardStatus.offline;

    final chip = switch (status) {
      RoomCardStatus.normal => StatusChipType.normal,
      RoomCardStatus.leak => StatusChipType.leak,
      RoomCardStatus.closed => StatusChipType.closedOnDark,
      RoomCardStatus.offline => StatusChipType.offline,
    };

    return CardSurface(
      color: _dark ? AppColors.ink : AppColors.surface,
      onTap: onTap,
      semanticLabel: name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headline.copyWith(color: fg),
                ),
              ),
              if (isHighest && !_dark) ...[
                const StatusChip(StatusChipType.highest),
                const SizedBox(width: AppSpacing.sm),
              ],
              StatusChip(chip),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Metric(
                  value: offline || todayLiters == null
                      ? null
                      : formatNumber(todayLiters!),
                  unit: 'L',
                  label: 'Hari ini',
                  fg: fg,
                  muted: muted,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _Metric(
                  value: offline || flowLpm == null
                      ? null
                      : formatNumber(flowLpm!),
                  unit: 'L/menit',
                  label: 'Debit sekarang',
                  fg: fg,
                  muted: muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _ValvePanel(
            title: valveTitle,
            subtitle: valveSubtitle,
            dark: _dark,
            switchState: switchState,
            onChanged: onValveChanged,
            roomName: name,
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.unit,
    required this.label,
    required this.fg,
    required this.muted,
  });

  final String? value;
  final String unit;
  final String label;
  final Color fg;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (value == null)
          Text(
            'Tidak ada data',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body.copyWith(color: muted),
          )
        else
          ValueWithUnit(value: value!, unit: unit, color: fg, unitColor: muted),
        Text(label, style: AppTextStyles.caption.copyWith(color: muted)),
      ],
    );
  }
}

class _ValvePanel extends StatelessWidget {
  const _ValvePanel({
    required this.title,
    required this.subtitle,
    required this.dark,
    required this.switchState,
    required this.onChanged,
    required this.roomName,
  });

  final String title;
  final String subtitle;
  final bool dark;
  final ValveSwitchState switchState;
  final ValueChanged<bool>? onChanged;
  final String roomName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        // Di kartu gelap, panel memakai on-dark tipis supaya tetap terpisah
        // tanpa border.
        color: dark ? AppColors.onDark.withValues(alpha: 0.08) : AppColors.bg,
        borderRadius: AppRadius.cardAll,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label.copyWith(
                    color: dark ? AppColors.onDark : AppColors.ink,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: dark
                        ? AppColors.onDark.withValues(alpha: 0.7)
                        : AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          ValveSwitch(
            state: switchState,
            dark: dark,
            onChanged: onChanged,
            semanticLabel: 'Valve $roomName',
          ),
        ],
      ),
    );
  }
}
