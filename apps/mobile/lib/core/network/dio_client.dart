import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import 'api_exception.dart';

/// Dio untuk REST `/v1` (CONTRACT.md bagian 3).
Dio createDio({String baseUrl = Env.apiBaseUrl, String token = Env.apiToken}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 10),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        // Semua endpoint kecuali /health memakai Bearer token.
        if (token.isNotEmpty && options.path != '/health') {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (e, handler) {
        handler.reject(
          DioException(
            requestOptions: e.requestOptions,
            response: e.response,
            type: e.type,
            error: ApiException.fromDio(e),
          ),
        );
      },
    ),
  );

  return dio;
}

final dioProvider = Provider<Dio>((ref) => createDio());
