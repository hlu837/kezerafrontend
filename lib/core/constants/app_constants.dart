/// Central place for values that are environment-specific or reused across
/// the app, so nothing is hard-coded at call sites.
class AppConstants {
  const AppConstants._();

  /// Matches the Express mount point on the backend: `app.use('/api/v1', ...)`.
  ///
  /// Override at build/run time instead of editing this file, e.g.:
  ///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
  ///
  /// Production URL: https://kezera-backend.vercel.app/api/v1
  /// Local development: http://localhost:3000/api/v1 (Android) or http://10.0.2.2:3000/api/v1
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://kezera-backend.vercel.app/api/v1',
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  // flutter_secure_storage keys
  static const String tokenStorageKey = 'kezera_token';
  static const String userStorageKey = 'kezera_user';

  /// Job ids a seeker has saved/bookmarked from the job board.
  /// On-device only for now (JS-03) — no backend endpoint yet.
  static const String savedJobIdsStorageKey = 'kezera_saved_job_ids';

  // Auth endpoints (relative to apiBaseUrl)
  static const String loginEndpoint = '/auth/login';
  static const String registerEndpoint = '/auth/register';
}
