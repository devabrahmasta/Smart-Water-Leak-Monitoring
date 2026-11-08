import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/alerts/alerts_page.dart';
import '../../features/demo/demo_page.dart';
import '../../features/gallery/component_gallery_page.dart';
import '../../features/home/home_page.dart';
import '../../features/room_detail/room_detail_page.dart';
import '../../features/rooms/rooms_page.dart';
import '../../features/usage/usage_page.dart';
import 'app_shell.dart';

/// Path rute. Detail Kamar ada di bawah tiap tab supaya tombol kembali dan
/// tab aktif tetap benar dari mana pun dibuka.
abstract final class AppRoutes {
  static const home = '/beranda';
  static const usage = '/beranda/grafik';
  static const demo = '/beranda/demo';
  static const rooms = '/kamar';
  static const alerts = '/notifikasi';

  static String homeRoom(int id) => '$home/kamar/$id';
  static String room(int id) => '$rooms/$id';
  static String alertRoom(int id) => '$alerts/kamar/$id';

  /// Galeri komponen R-10, hanya di build debug.
  static const gallery = '/galeri';
}

GoRoute _roomRoute(String path, String backTo) => GoRoute(
  path: path,
  builder: (context, state) => RoomDetailPage(
    roomId: int.parse(state.pathParameters['id']!),
    backTo: backTo,
  ),
);

GoRouter createRouter({String initialLocation = AppRoutes.home}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(navigationShell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (context, state) => const HomePage(),
              routes: [
                GoRoute(
                  path: 'grafik',
                  builder: (context, state) => const UsagePage(),
                ),
                GoRoute(
                  path: 'demo',
                  builder: (context, state) => const DemoPage(),
                ),
                _roomRoute('kamar/:id', AppRoutes.home),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.rooms,
              builder: (context, state) => const RoomsPage(),
              routes: [_roomRoute(':id', AppRoutes.rooms)],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.alerts,
              builder: (context, state) => const AlertsPage(),
              routes: [_roomRoute('kamar/:id', AppRoutes.alerts)],
            ),
          ],
        ),
      ],
    ),
    if (kDebugMode)
      GoRoute(
        path: AppRoutes.gallery,
        builder: (context, state) => const ComponentGalleryPage(),
      ),
  ],
);

final routerProvider = Provider<GoRouter>((ref) {
  final router = createRouter();
  ref.onDispose(router.dispose);
  return router;
});
