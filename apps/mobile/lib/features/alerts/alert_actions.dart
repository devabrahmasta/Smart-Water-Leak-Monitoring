import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../data/models/models.dart';
import '../../data/providers/providers.dart';
import '../valve/valve_actions.dart';
import 'alert_detail_sheet.dart';

/// Buka sheet detail alert. Untuk LEAK yang masih aktif (valve tertutup),
/// sheet berisi tombol Buka valve dengan alur US-08 (US-11).
Future<void> openAlertDetail(
  BuildContext context,
  WidgetRef ref, {
  required Alert alert,
  required String roomRoute,
}) {
  final canOpenValve =
      alert.type == AlertType.leak && alert.status == AlertStatus.open;
  return showAlertDetailSheet(
    context,
    alert: alert,
    onViewRoom: () => context.go(roomRoute),
    onOpenValve: canOpenValve
        ? () => requestValveChange(
            context,
            ref,
            roomId: alert.roomId,
            roomName: alert.roomName,
            open: true,
            closedByLeak: true,
          )
        : null,
  );
}

/// Ambil alert dari server lalu buka detailnya (dari banner atau push).
Future<void> openAlertById(
  BuildContext context,
  WidgetRef ref, {
  required int alertId,
  required String Function(int roomId) roomRoute,
}) async {
  try {
    final alert = await ref.read(repositoryProvider).getAlert(alertId);
    if (!context.mounted) return;
    await openAlertDetail(
      context,
      ref,
      alert: alert,
      roomRoute: roomRoute(alert.roomId),
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
