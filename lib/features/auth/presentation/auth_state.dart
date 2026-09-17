import 'package:equatable/equatable.dart';

import '../domain/user_model.dart';

enum AuthStatus {
  /// Startup hydration hasn't finished yet — show a splash/loading state.
  unknown,

  /// A login/register request is in flight.
  authenticating,

  authenticated,
  unauthenticated,
}

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.token,
    this.errorMessage,
  });

  final AuthStatus status;
  final AuthUser? user;
  final String? token;
  final String? errorMessage;

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && user != null && token != null;

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    String? token,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      token: token ?? this.token,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, user, token, errorMessage];
}
