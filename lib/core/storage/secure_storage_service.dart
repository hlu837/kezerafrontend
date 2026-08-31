import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_constants.dart';

/// Thin wrapper around [FlutterSecureStorage] so the rest of the app never
/// touches storage keys or the underlying package directly. Swapping the
/// persistence mechanism later only means editing this file.
class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _storage;

  Future<String?> readToken() =>
      _storage.read(key: AppConstants.tokenStorageKey);

  Future<void> saveToken(String token) =>
      _storage.write(key: AppConstants.tokenStorageKey, value: token);

  Future<String?> readUserJson() =>
      _storage.read(key: AppConstants.userStorageKey);

  Future<void> saveUserJson(String userJson) =>
      _storage.write(key: AppConstants.userStorageKey, value: userJson);

  /// Clears both the token and the cached user profile — used on logout
  /// and whenever the API reports the session is no longer valid (401).
  Future<void> clear() => Future.wait([
        _storage.delete(key: AppConstants.tokenStorageKey),
        _storage.delete(key: AppConstants.userStorageKey),
      ]);
}
