import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_controller.dart';
import 'features/auth/presentation/auth_provider.dart';
import 'features/auth/presentation/auth_state.dart';

void main() {
  runApp(const ProviderScope(child: KezearaJobsApp()));
}

class KezearaJobsApp extends ConsumerWidget {
  const KezearaJobsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final isHydrating =
        ref.watch(authProvider.select((s) => s.status)) == AuthStatus.unknown;
    final isDark = ref.watch(isDarkModeProvider);

    return MaterialApp.router(
      title: 'Kezera',
      debugShowCheckedModeBanner: false,
      theme: isDark ? AppTheme.dark : AppTheme.light,
      routerConfig: router,
      builder: (context, child) {
        // Startup token hydration (secure storage read) hasn't resolved
        // yet -- cover the router's initial /login flash with a splash
        // instead of letting the user see a login screen blink by.
        //
        // Swapping _SplashScreen straight for `child` (or vice versa) is
        // a hard cut between two full-screen widgets; on some devices the
        // frame in between briefly shows nothing but the raw window
        // background, which reads as a flash of "temporary black screen".
        // AnimatedSwitcher crossfades the two so there's always something
        // painted on screen during the swap.
        final content = isHydrating
            ? const _SplashScreen()
            : (child ?? const SizedBox.shrink());
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: KeyedSubtree(
            key: ValueKey(isHydrating),
            child: content,
          ),
        );
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Set explicitly rather than relying on the inherited Theme —
      // this screen can paint on the very first frame, before we want
      // to depend on anything but this widget's own styling, so it
      // matches the native launch background (see
      // android/app/src/main/res/drawable/launch_background.xml)
      // exactly and never shows an unstyled default background.
      backgroundColor: AppColors.background,
      body: Center(
        child: CircularProgressIndicator(
          // Explicit, on-brand color+width so the spinner reads clearly
          // against the black background instead of relying on theme
          // defaults resolving correctly at this early point.
          color: AppColors.green,
          strokeWidth: 3,
        ),
      ),
    );
  }
}
