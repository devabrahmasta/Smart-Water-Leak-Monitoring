import 'package:flutter/material.dart';

import '../../components/components.dart';
import '../../core/presentation/labels.dart';
import '../../data/models/models.dart';

/// [RoomCard] yang diisi dari model [Room]. Dipakai Beranda, Kamar, dan
/// Detail Kamar supaya tampilannya selalu sama.
///
/// [onValveChanged] null = saklar hanya menampilkan status (kontrol valve
/// disambungkan di R-12). [switchOverride] dipakai R-12 untuk state Pending.
class RoomCardView extends StatelessWidget {
  const RoomCardView({
    super.key,
    required this.room,
    this.onTap,
    this.onValveChanged,
    this.switchOverride,
    this.panelOverride,
  });

  final Room room;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onValveChanged;
  final ValveSwitchState? switchOverride;
  final ({String title, String subtitle})? panelOverride;

  @override
  Widget build(BuildContext context) {
    final panel = panelOverride ?? valvePanelText(room);
    return RoomCard(
      name: room.name,
      status: roomCardStatus(room.status),
      todayLiters: room.todayL,
      flowLpm: room.flowLpm,
      isHighest: room.isHighest,
      valveTitle: panel.title,
      valveSubtitle: panel.subtitle,
      switchState: switchOverride ?? valveSwitchState(room),
      onValveChanged: onValveChanged,
      onTap: onTap,
    );
  }
}
