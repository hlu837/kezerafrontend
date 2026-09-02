import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/auth_payloads.dart';
import 'auth_provider.dart';
import 'auth_state.dart';

/// Shared by every role. The backend doesn't care whether the caller is a
/// seeker, employer, or agency -- the role comes back on the user object,
/// and the router (see core/routing/app_router.dart) sends them to the
/// right dashboard from there. There's no role picker here on purpose.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    await ref.read(authProvider.notifier).login(
          LoginPayload.fromIdentifier(
            identifier: _identifierController.text,
            password: _passwordController.text,
          ),
        );
    // Navigation happens reactively: authProvider flips to `authenticated`,
    // go_router's redirect (app_router.dart) sees that on the next
    // refresh and sends the user to their role's dashboard.
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isSubmitting = authState.status == AuthStatus.authenticating;

    return Scaffold(
      // go_router's `go()` replaces the location rather than pushing, so
      // there's no back-stack entry to pop here — link back to the
      // landing page explicitly instead of a conditional BackButton.
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(onPressed: () => context.go('/jobs')),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            // Caps the form width on wide/web layouts instead of
            // stretching a login form across a desktop browser window.
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'KezearaJobs',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Welcome back. Sign in to continue.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                    const SizedBox(height: 32),
                    if (authState.errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          authState.errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _identifierController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username],
                      decoration: const InputDecoration(
                        labelText: 'Phone or Email',
                        hintText: '+251911234567 or you@example.com',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => (value == null || value.trim().isEmpty)
                          ? 'Phone or email is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Password is required'
                          : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: isSubmitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Sign in'),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: isSubmitting
                            ? null
                            : () => context.go('/register'),
                        child: const Text("Don't have an account? Create one"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
