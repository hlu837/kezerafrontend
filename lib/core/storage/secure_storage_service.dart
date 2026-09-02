import 'dart:convert';

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

  /// On-device job-save/bookmark list (see `SavedJobsNotifier`). Stores
  /// full job snapshots (not just ids) as raw JSON maps — kept generic
  /// here (no `Job` import) so `core/` doesn't reach into a feature's
  /// domain model; `SavedJobsNotifier` does the `Job.fromJson`/`toJson`
  /// conversion. Returns an empty list if nothing's been saved yet or
  /// the stored value is somehow malformed, rather than throwing and
  /// losing the feature.
  Future<List<Map<String, dynamic>>> readSavedJobsRaw() async {
    final raw = await _storage.read(key: AppConstants.savedJobIdsStorageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((entry) => entry as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSavedJobsRaw(List<Map<String, dynamic>> jobs) =>
      _storage.write(
        key: AppConstants.savedJobIdsStorageKey,
        value: jsonEncode(jobs),
      );
}
