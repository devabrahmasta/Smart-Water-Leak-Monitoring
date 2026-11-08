import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/providers.dart';
import '../router/app_router.dart';

/// Push kebocoran (US-12, US-13, CONTRACT.md bagian 4).
///
/// Backend mengirim pesan FCM bertipe `data`, jadi aplikasi sendiri yang
/// menampilkan notifikasi lewat flutter_local_notifications, baik saat
/// aplikasi terbuka maupun di latar belakang. Mengetuk notifikasi membuka
/// Detail Kamar yang bersangkutan (lihat [pushRoute]).
///
/// Firebase dikonfigurasi lewat `--dart-define` (lihat [firebaseOptions]),
/// tanpa `google-services.json`. Bila tidak diisi, push dimatikan dan
/// aplikasi tetap jalan normal.

const _channel = AndroidNotificationChannel(
  'alerts',
  'Kebocoran dan anomali',
  description: 'Peringatan kebocoran dan pemakaian tidak wajar',
  importance: Importance.high,
);

final _plugin = FlutterLocalNotificationsPlugin();

/// Opsi Firebase dari `--dart-define`. Null = push tidak aktif.
FirebaseOptions? get firebaseOptions {
  const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  const appId = String.fromEnvironment('FIREBASE_APP_ID');
  const senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  if ([apiKey, appId, senderId, projectId].any((v) => v.isEmpty)) return null;
  return const FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: senderId,
    projectId: projectId,
  );
}

Future<void> _initLocal({void Function(String? payload)? onTap}) async {
  await _plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
    onDidReceiveNotificationResponse: onTap == null
        ? null
        : (response) => onTap(response.payload),
  );
  await _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(_channel);
}

/// Tujuan saat notifikasi diketuk: Detail Kamar lewat tab Beranda, supaya
/// pemilik langsung melihat penjelasan dan langkah penanganan. Tanpa
/// `room_id` yang valid, jatuh ke sheet detail alert di tab Notifikasi.
String pushRoute(Map<String, dynamic> data) {
  final roomId = int.tryParse('${data['room_id']}');
  if (roomId != null) return AppRoutes.homeRoom(roomId);
  return '${AppRoutes.alerts}?alert=${data['alert_id']}';
}

/// Tampilkan notifikasi dari payload FCM `data` (semua nilai string).
Future<void> _showFromData(Map<String, dynamic> data) async {
  final type = data['type'];
  if (type != 'LEAK' && type != 'ANOMALY') return; // ACTIVITY tidak di-push.
  final alertId = int.tryParse('${data['alert_id']}') ?? 0;
  await _plugin.show(
    id: alertId,
    title: data['title'] as String?,
    body: data['body'] as String?,
    payload: pushRoute(data),
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  );
}

/// Mode demo: notifikasi kebocoran lokal dengan isi sama seperti push
/// backend (CONTRACT.md 4.2), muncul setelah [delay] supaya pengguna sempat
/// keluar dari aplikasi. Mengetuknya membuka Detail Kamar [roomId].
Future<void> showDemoLeakNotification({
  required int roomId,
  required String roomName,
  Duration delay = const Duration(seconds: 12),
}) async {
  await Future<void>.delayed(delay);
  await _showFromData({
    'type': 'LEAK',
    'alert_id': '0',
    'room_id': '$roomId',
    'title': 'Kebocoran terdeteksi',
    'body': '$roomName: aliran stabil terdeteksi. Valve sudah ditutup.',
  });
}

/// Handler pesan saat aplikasi di latar belakang atau tertutup.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  final options = firebaseOptions;
  if (options == null) return;
  await Firebase.initializeApp(options: options);
  await _initLocal();
  await _showFromData(message.data);
}

/// Status izin notifikasi Android 13+ (US-20).
Future<bool> notificationsEnabled() async {
  try {
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.areNotificationsEnabled() ??
        true;
  } catch (_) {
    return true; // Platform tanpa plugin (tes): anggap aktif.
  }
}

Future<bool> requestNotificationPermission() async {
  try {
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission() ??
        true;
  } catch (_) {
    return true;
  }
}

/// Dipanggil sekali dari `main.dart`.
class PushService {
  PushService(this._container);

  final ProviderContainer _container;

  void _openFromNotification(String? route) {
    if (route == null || route.isEmpty) return;
    _container.read(routerProvider).go(route);
  }

  Future<void> start() async {
    try {
      await _initLocal(onTap: _openFromNotification);

      // Aplikasi dibuka dari notifikasi saat tertutup.
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        _openFromNotification(launch!.notificationResponse?.payload);
      }

      // Minta izin saat pertama dibuka (US-20). Android hanya bertanya
      // sekali; setelah ditolak, Beranda menampilkan baris pengingat.
      await requestNotificationPermission();
      _container.invalidate(notificationsEnabledProvider);

      final options = firebaseOptions;
      if (options == null) {
        debugPrint('Push nonaktif: FIREBASE_* tidak diisi lewat --dart-define');
        return;
      }
      await Firebase.initializeApp(options: options);
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

      FirebaseMessaging.onMessage.listen((message) {
        _showFromData(message.data);
        // Data di layar ikut diperbarui tanpa menunggu polling.
        _container
          ..invalidate(summaryProvider)
          ..invalidate(roomsProvider)
          ..invalidate(alertsProvider);
      });

      // Kontrak memakai registration token FCM klasik (CONTRACT.md 3,
      // POST /v1/push-tokens). API baru register()/onRegistered memberi
      // Firebase Installation ID yang butuh cara kirim berbeda di backend,
      // jadi sementara tetap pakai getToken sampai kontrak diubah.
      final messaging = FirebaseMessaging.instance;
      // ignore: deprecated_member_use
      final token = await messaging.getToken();
      if (token != null) await _register(token);
      // ignore: deprecated_member_use
      messaging.onTokenRefresh.listen(_register);
    } catch (e) {
      // Push bukan syarat aplikasi jalan.
      debugPrint('Push gagal disiapkan: $e');
    }
  }

  Future<void> _register(String token) async {
    try {
      await _container.read(repositoryProvider).registerPushToken(token);
    } catch (e) {
      debugPrint('Gagal mendaftarkan token FCM: $e');
    }
  }
}

/// Apakah notifikasi diizinkan (US-20).
final notificationsEnabledProvider = FutureProvider<bool>(
  (ref) => notificationsEnabled(),
);

/// Baris "Notifikasi mati" ditutup pengguna (berlaku selama sesi).
class NotificationBannerDismissed extends Notifier<bool> {
  @override
  bool build() => false;

  void dismiss() => state = true;
}

final notificationBannerDismissedProvider =
    NotifierProvider<NotificationBannerDismissed, bool>(
      NotificationBannerDismissed.new,
    );
