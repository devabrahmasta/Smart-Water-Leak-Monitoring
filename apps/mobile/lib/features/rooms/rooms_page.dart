import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../core/presentation/labels.dart';
import '../../core/presentation/screen_body.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/models.dart';
import '../../data/providers/providers.dart';
import 'room_card_view.dart';

enum RoomFilter { all, attention, offline }

/// Daftar kamar (US-05). Filter dilakukan di aplikasi karena
/// `GET /v1/rooms` di kontrak tidak punya parameter filter.
class RoomsPage extends ConsumerStatefulWidget {
  const RoomsPage({super.key});

  @override
  ConsumerState<RoomsPage> createState() => _RoomsPageState();
}

class _RoomsPageState extends ConsumerState<RoomsPage> {
  RoomFilter _filter = RoomFilter.all;

  List<Room> _apply(List<Room> rooms) => switch (_filter) {
    RoomFilter.all => rooms,
    RoomFilter.attention => roomsNeedingAttention(rooms),
    RoomFilter.offline =>
      rooms.where((r) => r.status == RoomStatus.offline).toList(),
  };

  @override
  Widget build(BuildContext context) {
    final rooms = ref.watch(roomsProvider);

    return ScreenBody(
      onRefresh: () => refreshProvider(ref, roomsProvider.future),
      children: [
        const ScreenHeader.title(title: 'Kamar'),
        const SizedBox(height: AppSpacing.xxl),
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedControl<RoomFilter>(
            segments: const [
              (RoomFilter.all, 'Semua'),
              (RoomFilter.attention, 'Perlu dicek'),
              (RoomFilter.offline, 'Offline'),
            ],
            selected: _filter,
            onChanged: (f) => setState(() => _filter = f),
          ),
        ),
        cardGap,
        AsyncView<List<Room>>(
          value: rooms,
          onRetry: () => ref.invalidate(roomsProvider),
          builder: (all) {
            if (all.isEmpty) {
              return const EmptyState(
                icon: AppIcons.room,
                title: 'Belum ada kamar terhubung',
                message: 'Kamar muncul setelah perangkat mengirim data',
              );
            }
            final list = _apply(all);
            if (list.isEmpty) {
              return EmptyState(
                title: _filter == RoomFilter.offline
                    ? 'Semua perangkat online'
                    : 'Semua kamar normal',
                message: 'Tidak ada kamar di filter ini',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < list.length; i++) ...[
                  if (i > 0) cardGap,
                  RoomCardView(
                    room: list[i],
                    onTap: () => context.go(AppRoutes.room(list[i].id)),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}
