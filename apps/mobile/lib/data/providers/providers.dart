import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env.dart';
import '../../core/network/dio_client.dart';
import '../mock/mock_smart_water_repository.dart';
import '../models/models.dart';
import '../repository/http_smart_water_repository.dart';
import '../repository/smart_water_repository.dart';

/// Sumber data: mock (default) atau backend asli (`USE_MOCK=false`).
final repositoryProvider = Provider<SmartWaterRepository>((ref) {
  if (Env.useMock) {
    return MockSmartWaterRepository(
      scenario: MockScenario.parse(Env.mockScenario),
    );
  }
  return HttpSmartWaterRepository(ref.watch(dioProvider));
});

/// Interval polling layar aktif (US-01, CONTRACT.md 3). Null = mati (tes).
final pollIntervalProvider = Provider<Duration?>(
  (ref) => const Duration(seconds: 10),
);

extension _Polling on Ref {
  /// Muat ulang provider ini tiap interval selama masih didengar layar.
  /// Saat aplikasi di latar belakang, polling dilewati (US-01).
  void poll() {
    final interval = read(pollIntervalProvider);
    if (interval == null) return;
    final timer = Timer.periodic(interval, (_) {
      final state = WidgetsBinding.instance.lifecycleState;
      if (state == null || state == AppLifecycleState.resumed) {
        invalidateSelf();
      }
    });
    onDispose(timer.cancel);
  }
}

final summaryProvider = FutureProvider.autoDispose<Summary>((ref) {
  ref.poll();
  return ref.watch(repositoryProvider).getSummary();
});

final roomsProvider = FutureProvider.autoDispose<List<Room>>((ref) {
  ref.poll();
  return ref.watch(repositoryProvider).getRooms();
});

final roomDetailProvider = FutureProvider.autoDispose.family<RoomDetail, int>((
  ref,
  id,
) {
  ref.poll();
  return ref.watch(repositoryProvider).getRoom(id);
});

final roomCommandsProvider = FutureProvider.autoDispose
    .family<List<ValveCommand>, int>((ref, roomId) {
      ref.poll();
      return ref.watch(repositoryProvider).getRoomCommands(roomId, limit: 10);
    });

/// Grafik: [UsageQuery.roomId] null = semua kamar.
typedef UsageQuery = ({UsagePeriod period, int? roomId});

final usageProvider = FutureProvider.autoDispose.family<Usage, UsageQuery>((
  ref,
  q,
) {
  ref.poll();
  return ref.watch(repositoryProvider).getUsage(q.period, roomId: q.roomId);
});

/// Semua alert; layar Notifikasi memfilter di sisi aplikasi supaya
/// ganti tab filter tidak menunggu jaringan.
final alertsProvider = FutureProvider.autoDispose<List<Alert>>((ref) async {
  ref.poll();
  final page = await ref.watch(repositoryProvider).getAlerts(limit: 50);
  return page.items;
});

/// Jumlah alert OPEN untuk badge tab Notifikasi dan lonceng Beranda.
final openAlertCountProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(summaryProvider).value?.openAlertCount ?? 0;
});

/// Ada kebocoran yang belum selesai: Beranda dan Summary Card jadi merah,
/// kembali biru setelah semua kebocoran selesai.
final activeLeakProvider = Provider.autoDispose<bool>((ref) {
  final rooms = ref.watch(roomsProvider).value ?? const <Room>[];
  final latest = ref.watch(summaryProvider).value?.latestOpenAlert;
  return rooms.any((r) => r.status == RoomStatus.leak) ||
      latest?.type == AlertType.leak;
});

/// Ambang aturan kebocoran satu kamar.
final roomRulesProvider = FutureProvider.autoDispose.family<RoomRules, int>(
  (ref, roomId) => ref.watch(repositoryProvider).getRoomRules(roomId),
);

/// Skenario Kamar 2 yang terakhir dipilih di Mode demo (penanda di layar).
class SelectedDemoScenario extends Notifier<DemoScenarioKind?> {
  @override
  DemoScenarioKind? build() => null;

  void set(DemoScenarioKind scenario) => state = scenario;
}

final selectedDemoScenarioProvider =
    NotifierProvider<SelectedDemoScenario, DemoScenarioKind?>(
      SelectedDemoScenario.new,
    );

/// Muat ulang semua data setelah ada perubahan (mis. perintah valve sukses).
void refreshAll(WidgetRef ref) {
  ref
    ..invalidate(summaryProvider)
    ..invalidate(roomsProvider)
    ..invalidate(roomDetailProvider)
    ..invalidate(roomCommandsProvider)
    ..invalidate(alertsProvider)
    ..invalidate(usageProvider);
}
