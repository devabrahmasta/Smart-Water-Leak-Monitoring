import 'package:dio/dio.dart';

/// Kode galat dari CONTRACT.md bagian 3, plus dua kode lokal untuk
/// masalah jaringan yang tidak sampai ke server.
enum ApiErrorCode {
  unauthorized,
  notFound,
  deviceOffline,
  commandInProgress,
  invalidPayload,

  /// Server tidak terjangkau / timeout (US-19).
  network,

  /// Galat lain yang tidak dikenal.
  unknown;

  static ApiErrorCode fromContract(String? code) => switch (code) {
    'UNAUTHORIZED' => unauthorized,
    'NOT_FOUND' => notFound,
    'DEVICE_OFFLINE' => deviceOffline,
    'COMMAND_IN_PROGRESS' => commandInProgress,
    'INVALID_PAYLOAD' => invalidPayload,
    _ => unknown,
  };
}

class ApiException implements Exception {
  const ApiException(this.code, this.message, {this.statusCode});

  final ApiErrorCode code;
  final String message;
  final int? statusCode;

  /// Ubah DioException jadi ApiException dengan membaca format galat kontrak:
  /// `{ "error": { "code": "...", "message": "..." } }`.
  factory ApiException.fromDio(DioException e) {
    final response = e.response;
    if (response == null) {
      return const ApiException(
        ApiErrorCode.network,
        'Gagal terhubung ke server',
      );
    }
    final data = response.data;
    final error = data is Map ? data['error'] : null;
    if (error is Map) {
      return ApiException(
        ApiErrorCode.fromContract(error['code'] as String?),
        (error['message'] as String?) ?? 'Terjadi kesalahan',
        statusCode: response.statusCode,
      );
    }
    return ApiException(
      ApiErrorCode.unknown,
      'Terjadi kesalahan (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  @override
  String toString() => 'ApiException($code, $statusCode): $message';
}
