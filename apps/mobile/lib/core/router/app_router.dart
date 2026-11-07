import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/alerts/alerts_page.dart';
import '../../features/gallery/component_gallery_page.dart';
import '../../features/home/home_page.dart';
import '../../features/rooms/rooms_page.dart';
import 'app_shell.dart';

/// Path rute. Detail Grafik dan Detail Kamar ditambahkan di R-11.
abstract final class AppRoutes {
  static const home = '/beranda';
  static const rooms = '/kamar';
  static const alerts = '/notifikasi';

  /// Galeri komponen R-10, hanya di build debug.
  static const gallery = '/galeri';
}

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
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.rooms,
              builder: (context, state) => const RoomsPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.alerts,
              builder: (context, state) => const AlertsPage(),
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
