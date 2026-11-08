import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/components.dart';
import '../../core/presentation/labels.dart';
import '../../data/models/models.dart';
import '../../data/providers/providers.dart';
import '../valve/valve_actions.dart';
import '../valve/valve_controller.dart';

/// [RoomCard] yang diisi dari model [Room], lengkap dengan kendali valve.
/// Dipakai Beranda, Kamar, dan Detail Kamar supaya perilakunya sama.
///
/// Saklar:
/// - Pending selama menunggu ACK (US-07);
/// - disabled bila perangkat offline (US-09) atau server tidak terjangkau
///   (US-19).
class RoomCardView extends ConsumerWidget {
  const RoomCardView({super.key, required this.room, this.onTap});

  final Room room;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(
      valveControllerProvider.select((s) => s[room.id]),
    );
    final serverDown = ref.watch(roomsProvider.select((v) => v.hasError));

    final ({String title, String subtitle}) panel;
    final ValveSwitchState switchState;
    if (pending != null) {
      panel = (
        title: 'Menunggu alat',
        subtitle:
            'Perintah ${pending == CommandAction.open ? 'nyalakan' : 'matikan'} dikirim',
      );
      switchState = ValveSwitchState.pending;
    } else if (serverDown && room.status != RoomStatus.offline) {
      panel = (
        title: 'Kontrol tidak tersedia',
        subtitle: 'Server tidak terjangkau',
      );
      switchState = ValveSwitchState.disabled;
    } else {
      panel = valvePanelText(room);
      switchState = valveSwitchState(room);
    }

    final interactive =
        switchState == ValveSwitchState.on ||
        switchState == ValveSwitchState.off;

    return RoomCard(
      name: room.name,
      status: roomCardStatus(room.status),
      todayLiters: room.todayL,
      flowLpm: room.flowLpm,
      summary: roomSummary(room),
      isHighest: room.isHighest,
      valveTitle: panel.title,
      valveSubtitle: panel.subtitle,
      switchState: switchState,
      onTap: onTap,
      onValveChanged: interactive
          ? (open) => requestValveChange(
              context,
              ref,
              roomId: room.id,
              roomName: room.name,
              open: open,
              closedByLeak: room.status == RoomStatus.leak,
            )
          : null,
    );
  }
}
