import 'package:dio/dio.dart';

import '../../core/network/api_exception.dart';
import '../models/models.dart';
import 'smart_water_repository.dart';

/// Implementasi REST `/v1` (CONTRACT.md bagian 3).
class HttpSmartWaterRepository implements SmartWaterRepository {
  HttpSmartWaterRepository(this._dio);

  final Dio _dio;

  Future<T> _get<T>(
    String path,
    T Function(dynamic json) parse, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final res = await _dio.get<dynamic>(path, queryParameters: query);
      return parse(res.data);
    } on DioException catch (e) {
      throw e.error is ApiException ? e.error! : ApiException.fromDio(e);
    }
  }

  Map<String, dynamic> _map(dynamic j) => j as Map<String, dynamic>;

  @override
  Future<Summary> getSummary() =>
      _get('/v1/summary', (j) => Summary.fromJson(_map(j)));

  @override
  Future<List<Room>> getRooms() => _get(
    '/v1/rooms',
    (j) => [
      for (final r in _map(j)['rooms'] as List)
        Room.fromJson(r as Map<String, dynamic>),
    ],
  );

  @override
  Future<RoomDetail> getRoom(int id) =>
      _get('/v1/rooms/$id', (j) => RoomDetail.fromJson(_map(j)));

  @override
  Future<Usage> getUsage(UsagePeriod period, {int? roomId}) => _get(
    '/v1/usage',
    (j) => Usage.fromJson(_map(j)),
    query: {'period': period.name, 'room_id': ?roomId},
  );

  @override
  Future<AlertPage> getAlerts({AlertStatus? status, int? limit, int? before}) =>
      _get(
        '/v1/alerts',
        (j) => AlertPage.fromJson(_map(j)),
        query: {
          'status': status?.name ?? 'all',
          'limit': ?limit,
          'before': ?before,
        },
      );

  @override
  Future<Alert> getAlert(int id) =>
      _get('/v1/alerts/$id', (j) => Alert.fromJson(_map(j)));

  @override
  Future<List<ValveCommand>> getRoomCommands(int roomId, {int limit = 10}) =>
      _get(
        '/v1/rooms/$roomId/commands',
        commandsFromJson,
        query: {'limit': limit},
      );

  @override
  Future<int> sendValveCommand(int roomId, CommandAction action) async {
    try {
      final res = await _dio.post<dynamic>(
        '/v1/rooms/$roomId/valve',
        data: {'action': enumToContract(action)},
      );
      return (res.data as Map<String, dynamic>)['command_id'] as int;
    } on DioException catch (e) {
      throw e.error is ApiException ? e.error! : ApiException.fromDio(e);
    }
  }

  @override
  Future<ValveCommand> getCommand(int id) =>
      _get('/v1/commands/$id', (j) => ValveCommand.fromJson(_map(j)));

  @override
  Future<void> registerPushToken(String token) async {
    try {
      await _dio.post<dynamic>(
        '/v1/push-tokens',
        data: {'token': token, 'platform': 'android'},
      );
    } on DioException catch (e) {
      throw e.error is ApiException ? e.error! : ApiException.fromDio(e);
    }
  }
}
