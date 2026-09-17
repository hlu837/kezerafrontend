import 'package:dio/dio.dart';

import '../constants/app_constants.dart';
import '../error/api_exception.dart';
import '../storage/secure_storage_service.dart';

/// Configured [Dio] instance shared across the app.
///
/// Responsibilities:
/// 1. Auto-injects `Authorization: Bearer <token>` on every request when a
///    token is present in secure storage.
/// 2. Normalizes the backend's response envelope
///    (`{ status, message, errors }`) into a plain [ApiException] so
///    repositories/UI never parse raw Dio errors.
/// 3. Reports 401s via [onUnauthorized] so the auth layer can clear session
///    state, without this class needing to know about Riverpod/auth state.
class ApiClient {
  ApiClient({required SecureStorageService secureStorage})
      : _secureStorage = secureStorage,
        dio = Dio(
          BaseOptions(
            baseUrl: AppConstants.apiBaseUrl,
            connectTimeout: AppConstants.connectTimeout,
            receiveTimeout: AppConstants.receiveTimeout,
            headers: const {'Content-Type': 'application/json'},
          ),
        ) {
    dio.interceptors.addAll([_authInterceptor(), _errorInterceptor()]);
  }

  final Dio dio;
  final SecureStorageService _secureStorage;

  /// Set by the auth layer after construction. Called whenever a request
  /// fails with 401 (missing/expired/invalid token), so the app can fall
  /// back to a logged-out state on the next rebuild.
  void Function()? onUnauthorized;

  InterceptorsWrapper _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _secureStorage.readToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    );
  }

  InterceptorsWrapper _errorInterceptor() {
    return InterceptorsWrapper(
      onError: (DioException error, handler) async {
        if (error.response?.statusCode == 401) {
          await _secureStorage.clear();
          onUnauthorized?.call();
        }
        handler.reject(_asApiException(error));
      },
    );
  }

  /// Extracts a clean, user-facing message + field errors from the
  /// backend's `{ status, message, errors }` envelope, wrapping everything
  /// in a [DioException] whose `.error` is an [ApiException].
  DioException _asApiException(DioException error) {
    final data = error.response?.data;
    List<ApiFieldError>? fieldErrors;
    String message;

    if (data is Map<String, dynamic>) {
      final rawErrors = data['errors'];
      if (rawErrors is List) {
        fieldErrors = rawErrors
            .whereType<Map<String, dynamic>>()
            .map(ApiFieldError.fromJson)
            .toList();
      }

      final backendMessage = data['message'] as String?;
      final validationDetail = (fieldErrors == null || fieldErrors.isEmpty)
          ? null
          : fieldErrors.map((e) => e.message).join(', ');

      message = validationDetail ??
          backendMessage ??
          error.message ??
          'Something went wrong. Please try again.';
    } else if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      message = 'The connection timed out. Please try again.';
    } else if (error.type == DioExceptionType.connectionError) {
      message = 'Unable to reach the server. Check your connection.';
    } else {
      message = error.message ?? 'Something went wrong. Please try again.';
    }

    return error.copyWith(
      error: ApiException(
        message: message,
        statusCode: error.response?.statusCode,
        errors: fieldErrors,
      ),
    );
  }
}
