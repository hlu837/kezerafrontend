import 'package:dio/dio.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/auth_payloads.dart';
import '../domain/user_model.dart';

/// Result shared by both login and register: the backend returns
/// `{ user, token }` (register also returns a `profile`, which this app
/// doesn't need to hold onto after signup).
class AuthResult {
  const AuthResult({required this.user, required this.token});

  final AuthUser user;
  final String token;

  factory AuthResult.fromEnvelope(Map<String, dynamic> envelope) {
    final data = envelope['data'] as Map<String, dynamic>;
    return AuthResult(
      user: AuthUser.fromJson(data['user'] as Map<String, dynamic>),
      token: data['token'] as String,
    );
  }
}

/// Talks to the `/auth` endpoints. Knows nothing about state management or
/// storage — it just turns payloads into results, so it stays easy to test.
class AuthRepository {
  AuthRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<AuthResult> login(LoginPayload payload) => _guard(() async {
        final response = await _apiClient.dio.post<Map<String, dynamic>>(
          AppConstants.loginEndpoint,
          data: payload.toJson(),
        );
        return AuthResult.fromEnvelope(response.data!);
      });

  Future<AuthResult> register(RegisterPayload payload) => _guard(() async {
        final response = await _apiClient.dio.post<Map<String, dynamic>>(
          AppConstants.registerEndpoint,
          data: payload.toJson(),
        );
        return AuthResult.fromEnvelope(response.data!);
      });

  /// Runs [action] and rethrows Dio's `.error` (an [ApiException] set by
  /// [ApiClient]'s interceptor) instead of the raw [DioException], so
  /// callers only ever deal with [ApiException].
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      final apiError = e.error;
      if (apiError is ApiException) throw apiError;
      throw ApiException(message: e.message ?? 'Something went wrong.');
    }
  }
}
