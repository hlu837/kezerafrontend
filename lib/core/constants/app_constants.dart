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

  /// Gebeta Maps API key — powers the "Find an expert near you" map
  /// (nearby_experts_map_screen.dart). Override at build/run time, same
  /// convention as [apiBaseUrl]:
  ///   flutter run --dart-define=GEBETA_MAPS_API_KEY=your-key-here
  /// Left blank by default rather than a real key committed to source —
  /// the map screen shows a "map unavailable" state if this is empty.
  static const String gebetaMapsApiKey = String.fromEnvironment(
    'GEBETA_MAPS_API_KEY',
    defaultValue: '',
  );

  // flutter_secure_storage keys
  static const String tokenStorageKey = 'kezera_token';
  static const String userStorageKey = 'kezera_user';

  /// Job ids a seeker has saved/bookmarked from the job board.
  /// On-device only for now (JS-03) — no backend endpoint yet.
  static const String savedJobIdsStorageKey = 'kezera_saved_job_ids';

  /// Light/dark theme choice from Settings. Stores 'dark' or 'light';
  /// absent (new install / never toggled) means light.
  static const String themeModeStorageKey = 'kezera_theme_mode';

  // Auth endpoints (relative to apiBaseUrl)
  static const String loginEndpoint = '/auth/login';
  static const String registerEndpoint = '/auth/register';
}
