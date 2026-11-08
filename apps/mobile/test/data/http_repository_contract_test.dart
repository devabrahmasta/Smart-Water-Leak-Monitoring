import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_water/core/network/api_exception.dart';
import 'package:smart_water/core/network/dio_client.dart';
import 'package:smart_water/data/models/models.dart';
import 'package:smart_water/data/repository/http_smart_water_repository.dart';

/// Repository HTTP diuji terhadap fixture milik backend di
/// `packages/contracts/fixtures` (CONTRACT.md 5: semua jalur memakai
/// fixture yang sama). Kalau backend mengubah bentuk respons, tes ini gagal.

const _fixtures = '../../packages/contracts/fixtures';

Object? _fixture(String name) =>
    jsonDecode(File('$_fixtures/$name.json').readAsStringSync());

class _Recorded {
  _Recorded(this.method, this.path, this.query, this.headers, this.body);
  final String method;
  final String path;
  final Map<String, dynamic> query;
  final Map<String, dynamic> headers;
  final Object? body;
}

/// Adapter palsu: memetakan "METHOD path" ke (status, body).
class _FakeBackend implements HttpClientAdapter {
  _FakeBackend(this.routes);

  final Map<String, (int, Object?)> routes;
  final calls = <_Recorded>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(
      _Recorded(
        options.method,
        options.path,
        options.queryParameters,
        options.headers,
        options.data,
      ),
    );
    final route = routes['${options.method} ${options.path}'];
    if (route == null) {
      return ResponseBody.fromString(
        jsonEncode({
          'error': {'code': 'NOT_FOUND', 'message': 'tidak ada'},
        }),
        404,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    final (status, body) = route;
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

(HttpSmartWaterRepository, _FakeBackend) _repo(Map<String, (int, Object?)> r) {
  final backend = _FakeBackend(r);
  final dio = createDio(baseUrl: 'http://backend.test', token: 'rahasia')
    ..httpClientAdapter = backend;
  return (HttpSmartWaterRepository(dio), backend);
}

void main() {
  test('fixture backend ada (dijalankan dari apps/mobile)', () {
    expect(Directory(_fixtures).existsSync(), isTrue);
  });

  test('semua GET memakai Bearer token dan mem-parse fixture', () async {
    final (repo, backend) = _repo({
      'GET /v1/summary': (200, _fixture('rest_summary')),
      'GET /v1/rooms': (200, _fixture('rest_rooms')),
      'GET /v1/rooms/1': (200, _fixture('rest_room_detail')),
      'GET /v1/rooms/2/commands': (200, _fixture('rest_commands')),
      'GET /v1/usage': (200, _fixture('rest_usage_daily')),
      'GET /v1/alerts': (200, _fixture('rest_alerts')),
      'GET /v1/alerts/31': (200, _fixture('rest_alert_detail')),
    });

    final summary = await repo.getSummary();
    expect(summary.openAlertCount, 1);

    final rooms = await repo.getRooms();
    expect(rooms.last.status, RoomStatus.offline);
    expect(rooms.last.todayL, isNull);

    final detail = await repo.getRoom(1);
    expect(detail.recentAlerts.single.rule, AlertRule.continuous);

    final commands = await repo.getRoomCommands(2);
    expect(commands.single.status, CommandStatus.pending);

    final usage = await repo.getUsage(UsagePeriod.daily, roomId: 1);
    expect(usage.byRoom.single.volumeL, 1100.2);

    final alerts = await repo.getAlerts(status: AlertStatus.open, limit: 50);
    expect(alerts.nextBefore, 28);

    final alert = await repo.getAlert(31);
    expect(alert.detail['duration_min'], 45);

    for (final c in backend.calls) {
      expect(c.headers['Authorization'], 'Bearer rahasia', reason: c.path);
    }
    final usageCall = backend.calls.firstWhere((c) => c.path == '/v1/usage');
    expect(usageCall.query, {'period': 'daily', 'room_id': 1});
    final alertsCall = backend.calls.firstWhere((c) => c.path == '/v1/alerts');
    expect(alertsCall.query, {'status': 'open', 'limit': 50});
  });

  test('POST valve mengirim action huruf besar dan membaca 202', () async {
    final (repo, backend) = _repo({
      'POST /v1/rooms/2/valve': (202, {'command_id': 512, 'status': 'PENDING'}),
    });
    expect(await repo.sendValveCommand(2, CommandAction.open), 512);
    expect(backend.calls.single.body, {'action': 'OPEN'});
  });

  test('409 DEVICE_OFFLINE dibaca dari format galat kontrak', () async {
    final (repo, _) = _repo({
      'POST /v1/rooms/2/valve': (
        409,
        {
          'error': {
            'code': 'DEVICE_OFFLINE',
            'message': 'Perangkat Kamar 2 sedang offline',
          },
        },
      ),
    });
    await expectLater(
      repo.sendValveCommand(2, CommandAction.close),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', ApiErrorCode.deviceOffline)
            .having((e) => e.statusCode, 'status', 409),
      ),
    );
  });

  test('401 UNAUTHORIZED saat token salah', () async {
    final (repo, _) = _repo({
      'GET /v1/summary': (
        401,
        {
          'error': {'code': 'UNAUTHORIZED', 'message': 'Token tidak valid'},
        },
      ),
    });
    await expectLater(
      repo.getSummary(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'code',
          ApiErrorCode.unauthorized,
        ),
      ),
    );
  });

  test('ambang kamar: GET fixture dan PUT nilai detik', () async {
    final (repo, backend) = _repo({
      'GET /v1/rooms/1/rules': (200, _fixture('rest_room_rules')),
      'PUT /v1/rooms/1/rules': (
        200,
        {
          'room_id': 1,
          'continuous_sec': 600,
          'stable_sec': 1800,
          'quiet_sec': 900,
          'quiet_start': '22:00',
          'quiet_end': '05:00',
        },
      ),
    });
    final rules = await repo.getRoomRules(1);
    expect(rules.continuousSec, 2700);
    final updated = await repo.updateRoomRules(
      const RoomRules(
        roomId: 1,
        continuousSec: 600,
        stableSec: 1800,
        quietSec: 900,
        quietStart: '22:00',
        quietEnd: '05:00',
      ),
    );
    expect(updated.stableSec, 1800);
    expect(backend.calls.last.body, {
      'continuous_sec': 600,
      'stable_sec': 1800,
      'quiet_sec': 900,
      'quiet_start': '22:00',
      'quiet_end': '05:00',
    });
  });

  test('skenario demo: enum huruf besar, kamar nyata ditolak', () async {
    final (repo, backend) = _repo({
      'POST /v1/rooms/2/demo-scenario': (202, _fixture('demo_leak_stable')),
      'POST /v1/rooms/1/demo-scenario': (
        409,
        {
          'error': {
            'code': 'NOT_SIMULATED',
            'message': 'Kamar 1 memakai alat asli',
          },
        },
      ),
    });
    await repo.setDemoScenario(2, DemoScenarioKind.leakStable);
    expect(backend.calls.single.body, {'scenario': 'LEAK_STABLE'});
    await expectLater(
      repo.setDemoScenario(1, DemoScenarioKind.leakStable),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)),
    );
  });

  test('push token: POST 204 tanpa body', () async {
    final (repo, backend) = _repo({'POST /v1/push-tokens': (204, null)});
    await repo.registerPushToken('fcm-abc');
    expect(backend.calls.single.body, {
      'token': 'fcm-abc',
      'platform': 'android',
    });
  });
}
