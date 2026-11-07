import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/models.dart';
import '../../data/providers/providers.dart';

/// Hasil akhir satu perintah valve.
sealed class ValveResult {
  const ValveResult();
}

class ValveSucceeded extends ValveResult {
  const ValveSucceeded();
}

/// ACK FAILED dari backend atau tidak ada jawaban dalam batas waktu (US-07).
class ValveTimedOut extends ValveResult {
  const ValveTimedOut();
}

/// Ditolak sebelum dikirim (DEVICE_OFFLINE, COMMAND_IN_PROGRESS, jaringan).
class ValveRejected extends ValveResult {
  const ValveRejected(this.error);
  final ApiException error;
}

/// Interval polling status perintah (CONTRACT.md 3: tiap 1 detik).
final commandPollIntervalProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 1),
);

/// Batas tunggu di aplikasi (CONTRACT.md 3: maksimal 20 detik; backend
/// sendiri menandai FAILED setelah 15 detik).
final commandMaxWaitProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 20),
);

/// Perintah yang sedang menunggu ACK, per `room_id`. Selama ada di sini,
/// saklar kamar itu tampil Pending dan tidak bisa disentuh (US-07).
class ValveController extends Notifier<Map<int, CommandAction>> {
  @override
  Map<int, CommandAction> build() => const {};

  bool isPending(int roomId) => state.containsKey(roomId);

  Future<ValveResult> send(int roomId, CommandAction action) async {
    if (isPending(roomId)) {
      return const ValveRejected(
        ApiException(
          ApiErrorCode.commandInProgress,
          'Masih ada perintah yang menunggu',
        ),
      );
    }
    final repo = ref.read(repositoryProvider);
    final interval = ref.read(commandPollIntervalProvider);
    final maxWait = ref.read(commandMaxWaitProvider);

    state = {...state, roomId: action};
    try {
      final int commandId;
      try {
        commandId = await repo.sendValveCommand(roomId, action);
      } on ApiException catch (e) {
        return ValveRejected(e);
      }

      // Hitung jumlah polling, bukan jam dinding, supaya batas waktu tetap
      // benar walau jam HP berubah (dan bisa dites dengan waktu palsu).
      final maxPolls = (maxWait.inMilliseconds / interval.inMilliseconds)
          .ceil();
      for (var i = 0; i < maxPolls; i++) {
        await Future<void>.delayed(interval);
        if (!ref.mounted) return const ValveTimedOut();
        try {
          final cmd = await repo.getCommand(commandId);
          switch (cmd.status) {
            case CommandStatus.success:
              return const ValveSucceeded();
            case CommandStatus.failed:
              return const ValveTimedOut();
            case CommandStatus.pending:
              break;
          }
        } on ApiException {
          // Gangguan sesaat saat polling: coba lagi sampai batas waktu.
        }
      }
      return const ValveTimedOut();
    } finally {
      if (ref.mounted) state = {...state}..remove(roomId);
    }
  }
}

final valveControllerProvider =
    NotifierProvider<ValveController, Map<int, CommandAction>>(
      ValveController.new,
    );
