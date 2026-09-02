import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
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

    return MaterialApp.router(
      title: 'KezearaJobs',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      builder: (context, child) {
        // Startup token hydration (secure storage read) hasn't resolved
        // yet -- cover the router's initial /login flash with a splash
        // instead of letting the user see a login screen blink by.
        if (isHydrating) {
          return const _SplashScreen();
        }
        return child ?? const SizedBox.shrink();
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
