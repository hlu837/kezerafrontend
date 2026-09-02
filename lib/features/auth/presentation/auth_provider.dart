import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../data/auth_repository.dart';
import '../domain/auth_payloads.dart';
import '../domain/user_model.dart';
import 'auth_state.dart';

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final secureStorage = ref.watch(secureStorageServiceProvider);
  return ApiClient(secureStorage: secureStorage);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});

/// App-wide auth state. Hydrates from secure storage on creation, and is
/// the single source of truth for whether a user is logged in.
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final notifier = AuthNotifier(
    repository: ref.watch(authRepositoryProvider),
    secureStorage: ref.watch(secureStorageServiceProvider),
  );

  // Let the HTTP layer force a logout when it sees a 401, without ApiClient
  // needing to know anything about Riverpod or auth state.
  ref.watch(apiClientProvider).onUnauthorized = notifier.forceLogout;

  return notifier;
});

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier({
    required AuthRepository repository,
    required SecureStorageService secureStorage,
  })  : _repository = repository,
        _secureStorage = secureStorage,
        super(const AuthState()) {
    _hydrate();
  }

  final AuthRepository _repository;
  final SecureStorageService _secureStorage;

  /// Restores session from secure storage on app startup. No network call —
  /// the backend has no `/auth/me` endpoint, so the cached user (saved
  /// alongside the token at login/register time) is treated as the source
  /// of truth until it's cleared by logout or a 401.
  Future<void> _hydrate() async {
    try {
      final token = await _secureStorage.readToken();
      final userJson = await _secureStorage.readUserJson();

      if (token == null || token.isEmpty || userJson == null) {
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }

      final user = AuthUser.fromJson(
        jsonDecode(userJson) as Map<String, dynamic>,
      );
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
        token: token,
      );
    } catch (_) {
      // Corrupt/unreadable cache — fail safe into a logged-out state.
      await _secureStorage.clear();
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> login(LoginPayload payload) async {
    state = state.copyWith(
      status: AuthStatus.authenticating,
      clearError: true,
    );
    try {
      final result = await _repository.login(payload);
      await _persistSession(result);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: e.message,
      );
      return false;
    }
  }

  Future<bool> register(RegisterPayload payload) async {
    state = state.copyWith(
      status: AuthStatus.authenticating,
      clearError: true,
    );
    try {
      final result = await _repository.register(payload);
      await _persistSession(result);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: e.message,
      );
      return false;
    }
  }

  Future<void> logout() async {
    await _secureStorage.clear();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Called by [ApiClient] when a request comes back 401. Storage is
  /// already cleared by the client at that point — this just syncs state.
  void forceLogout() {
    if (state.status != AuthStatus.authenticated) return;
    state = const AuthState(
      status: AuthStatus.unauthenticated,
      errorMessage: 'Your session has expired. Please log in again.',
    );
  }

  void clearError() {
    if (state.errorMessage == null) return;
    state = state.copyWith(clearError: true);
  }

  Future<void> _persistSession(AuthResult result) async {
    await _secureStorage.saveToken(result.token);
    await _secureStorage.saveUserJson(jsonEncode(result.user.toJson()));
    state = AuthState(
      status: AuthStatus.authenticated,
      user: result.user,
      token: result.token,
    );
  }
}
