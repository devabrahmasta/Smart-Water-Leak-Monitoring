import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/components.dart';
import '../../core/network/api_exception.dart';
import '../../data/models/models.dart';
import '../../data/providers/providers.dart';
import 'valve_controller.dart';

/// Alur lengkap ubah valve dari UI (US-07, US-08):
/// Confirm Sheet → kirim → saklar Pending → polling ACK → Toast.
/// Status valve di layar baru berubah setelah data dimuat ulang dari server.
Future<void> requestValveChange(
  BuildContext context,
  WidgetRef ref, {
  required int roomId,
  required String roomName,
  required bool open,
  bool closedByLeak = false,
}) async {
  final confirmed = await showConfirmSheet(
    context,
    action: open ? ConfirmSheetAction.open : ConfirmSheetAction.close,
    title: '${open ? 'Nyalakan' : 'Matikan'} air $roomName?',
    message: open
        ? closedByLeak
              ? 'Air dihentikan otomatis karena terdeteksi bocor. Nyalakan hanya kalau keran dan pipa sudah dicek. Kebocoran akan ditandai selesai.'
              : 'Air di $roomName akan mengalir lagi.'
        : 'Air di $roomName berhenti mengalir sampai dinyalakan lagi.',
    confirmLabel: open ? 'Nyalakan air' : 'Matikan air',
  );
  // Batal tidak mengirim apa pun.
  if (!confirmed || !context.mounted) return;

  final result = await ref
      .read(valveControllerProvider.notifier)
      .send(roomId, open ? CommandAction.open : CommandAction.close);
  if (!context.mounted) return;

  switch (result) {
    case ValveSucceeded():
      refreshAll(ref);
      showToast(
        context,
        type: ToastType.success,
        message: 'Air $roomName ${open ? 'menyala' : 'dimatikan'}',
      );
    case ValveTimedOut():
      refreshAll(ref);
      showToast(
        context,
        type: ToastType.error,
        message: 'Alat tidak merespons. Coba lagi',
      );
    case ValveRejected(:final error):
      showToast(
        context,
        type: ToastType.error,
        message: switch (error.code) {
          ApiErrorCode.deviceOffline => 'Alat di $roomName sedang offline',
          ApiErrorCode.commandInProgress =>
            'Masih menunggu perintah sebelumnya',
          ApiErrorCode.network => 'Gagal terhubung ke server',
          _ => error.message,
        },
      );
  }
}
