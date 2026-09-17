import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_provider.dart' show secureStorageServiceProvider;
import 'app_theme.dart';

/// Whether dark mode is on. Defaults to `false` (light/white — matches
/// the reference mock) until the persisted value, if any, loads from
/// secure storage.
///
/// [AppThemeController.isDark] is kept in sync with this provider's state
/// on every change (see the notifier below), because a handful of
/// widgets read that flag directly (via [AppColors]) instead of going
/// through `Theme.of(context)` — see app_theme.dart for why.
final isDarkModeProvider = NotifierProvider<ThemeModeNotifier, bool>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<bool> {
  @override
  bool build() {
    // Fire-and-forget: loads the saved preference (if any) once secure
    // storage responds, then applies it. Starting synchronously with
    // `false` means the very first frame is always the light theme,
    // which is what we want rather than a flash of the wrong theme
    // while storage is read.
    _hydrate();
    return false;
  }

  Future<void> _hydrate() async {
    final saved = await ref.read(secureStorageServiceProvider).readIsDarkMode();
    if (saved != null && saved != state) {
      _apply(saved);
    }
  }

  Future<void> toggle() => setDark(!state);

  Future<void> setDark(bool isDark) async {
    _apply(isDark);
    await ref.read(secureStorageServiceProvider).saveIsDarkMode(isDark);
  }

  void _apply(bool isDark) {
    AppThemeController.isDark = isDark;
    state = isDark;
  }
}
