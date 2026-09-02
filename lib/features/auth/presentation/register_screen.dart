import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/auth_payloads.dart';
import 'auth_provider.dart';
import 'auth_state.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  int _currentStep = 0; // 0 = Basic Info, 1 = Plan Selection (for Employer/Agency)

  RegisterableRole _role = RegisterableRole.seeker;

  // Shared
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Seeker
  final _fullNameController = TextEditingController();

  // Employer
  final _companyNameController = TextEditingController();
  final _backofficePhoneController = TextEditingController();
  final _promoDetailsController = TextEditingController();

  // Agency
  final _agencyNameController = TextEditingController();
  final _operationalCityController = TextEditingController();

  // Business Verification (Employer / Agency)
  final _tinNumberController = TextEditingController();
  String _selectedSubscriptionTier = 'premium';

  static final _phonePattern = RegExp(r'^\+?[0-9]{7,15}$');
  static final _emailPattern = RegExp(r'^\S+@\S+\.\S+$');

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _companyNameController.dispose();
    _backofficePhoneController.dispose();
    _promoDetailsController.dispose();
    _agencyNameController.dispose();
    _operationalCityController.dispose();
    _tinNumberController.dispose();
    super.dispose();
  }

  RegisterPayload _buildPayload() {
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final tinNumber = _tinNumberController.text.trim();

    switch (_role) {
      case RegisterableRole.seeker:
        return RegisterPayload.seeker(
          phone: phone,
          password: password,
          fullName: _fullNameController.text.trim(),
          email: email,
        );
      case RegisterableRole.employer:
        return RegisterPayload.employer(
          phone: phone,
          password: password,
          companyName: _companyNameController.text.trim(),
          tinNumber: tinNumber,
          subscriptionTier: _selectedSubscriptionTier,
          email: email,
          backofficePhone: _backofficePhoneController.text.trim().isEmpty
              ? null
              : _backofficePhoneController.text.trim(),
          promoDetails: _promoDetailsController.text.trim().isEmpty
              ? null
              : _promoDetailsController.text.trim(),
        );
      case RegisterableRole.agency:
        return RegisterPayload.agency(
          phone: phone,
          password: password,
          agencyName: _agencyNameController.text.trim(),
          tinNumber: tinNumber,
          subscriptionTier: _selectedSubscriptionTier,
          email: email,
          operationalCity: _operationalCityController.text.trim().isEmpty
              ? null
              : _operationalCityController.text.trim(),
        );
    }
  }

  void _nextStep() {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmPasswordController.text) {
      ref.read(authProvider.notifier).clearError();
      _showFormError('Passwords do not match.');
      return;
    }

    if (_role == RegisterableRole.seeker) {
      _submit();
    } else {
      setState(() => _currentStep = 1);
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final success =
        await ref.read(authProvider.notifier).register(_buildPayload());

    if (!success || !mounted) return;

    if (_role == RegisterableRole.seeker) {
      // SEEK-01: a brand-new seeker's next stop is the category &
      // location preference screen, not straight to the dashboard the
      // router's redirect would otherwise send them to. Explicit here
      // (rather than only relying on redirect logic) keeps that guard
      // simple — it only has to know seeker routes stay under
      // '/seeker/*', not track an onboarding-complete flag.
      context.go('/seeker/onboarding/preferences');
    } else {
      _initiateChapaPayment();
    }
  }

  Future<void> _initiateChapaPayment() async {
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.dio.post<Map<String, dynamic>>(
        '/payments/initialize-subscription',
        data: {'plan': _selectedSubscriptionTier},
      );

      final checkoutUrl = (response.data!['data']
          as Map<String, dynamic>)['checkoutUrl'] as String;

      // This used to just show the checkout URL in a SnackBar instead of
      // opening it, so nobody ever actually reached Chapa to pay — which
      // meant `GET /payments/verify-callback` (the thing that flips a
      // brand-new employer/agency from `payment_pending` to `pending`)
      // never fired, and the account sat invisible to
      // admin.service.js#listVerifications (which only lists `pending`
      // accounts) forever. Launching the URL for real is what actually
      // gets them through checkout and into the admin approval queue.
      final launched = await launchUrl(
        Uri.parse(checkoutUrl),
        mode: LaunchMode.externalApplication,
      );

      if (!mounted) return;

      if (!launched) {
        // Couldn't open a browser/webview for some reason — leave them a
        // way to retry rather than silently stranding the account at
        // `payment_pending`. `/verification-status` also has a "Pay Now"
        // retry button for this same reason.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Couldn't open the payment page. You can retry from the "
              'verification status screen.',
            ),
          ),
        );
      }

      // The router's redirect guard already sends an unapproved
      // employer/agency to /verification-status on its own once the auth
      // state updates, but that only re-runs on a state change — since
      // opening an external browser doesn't trigger one, navigate there
      // explicitly so they're not left sitting on the registration form.
      context.go('/verification-status');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not start the payment process. Please try again from '
            'the verification status screen.',
          ),
        ),
      );
      context.go('/verification-status');
    }
  }

  void _showFormError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isSubmitting = authState.status == AuthStatus.authenticating;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _currentStep == 0 ? 'Create Account' : 'Choose Subscription Plan',
          style: const TextStyle(
            color: AppColors.ink,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.ink, size: 20),
          onPressed: _currentStep == 1
              ? () => setState(() => _currentStep = 0)
              // Step 0 has nowhere else to go back to internally — send
              // guests back to the public job listing they applied from.
              : () => context.go('/jobs'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: _currentStep == 0
                  ? _buildStep1BasicInfo(context, authState, isSubmitting)
                  : _buildStep2SubscriptionPlans(context, isSubmitting),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1: Basic Information
  // ---------------------------------------------------------------------------

  Widget _buildStep1BasicInfo(
      BuildContext context, AuthState authState, bool isSubmitting) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                const Text(
                  'Join KezearaJobs',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Select your role to view required fields',
                  style: TextStyle(
                    color: AppColors.inkMuted,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),

                // Custom Role Selector Bar
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      _RoleTab(
                        label: 'Job Seeker',
                        icon: Icons.person_outline,
                        isSelected: _role == RegisterableRole.seeker,
                        onTap: isSubmitting
                            ? null
                            : () => setState(() => _role = RegisterableRole.seeker),
                      ),
                      _RoleTab(
                        label: 'Company',
                        icon: Icons.business_outlined,
                        isSelected: _role == RegisterableRole.employer,
                        onTap: isSubmitting
                            ? null
                            : () => setState(() => _role = RegisterableRole.employer),
                      ),
                      _RoleTab(
                        label: 'Agency',
                        icon: Icons.corporate_fare_outlined,
                        isSelected: _role == RegisterableRole.agency,
                        onTap: isSubmitting
                            ? null
                            : () => setState(() => _role = RegisterableRole.agency),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Error Banner
          if (authState.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.errorSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      authState.errorMessage!,
                      style: const TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Role-specific fields
          ..._roleSpecificFields(isSubmitting),

          // Phone
          _buildTextField(
            controller: _phoneController,
            label: 'Phone Number',
            hint: '+251911234567',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            enabled: !isSubmitting,
            validator: (value) {
              final v = value?.trim() ?? '';
              if (v.isEmpty) return 'Phone number is required.';
              if (!_phonePattern.hasMatch(v)) {
                return 'Enter a valid phone number (7–15 digits).';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),

          // Email
          _buildTextField(
            controller: _emailController,
            label: 'Email Address',
            hint: 'user@example.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            enabled: !isSubmitting,
            validator: (value) {
              final v = value?.trim() ?? '';
              if (v.isEmpty) return 'Email address is required.';
              if (!_emailPattern.hasMatch(v)) return 'Enter a valid email address.';
              return null;
            },
          ),
          const SizedBox(height: 18),

          // Password
          _buildTextField(
            controller: _passwordController,
            label: 'Password',
            hint: 'At least 8 characters',
            icon: Icons.lock_outline,
            obscureText: true,
            enabled: !isSubmitting,
            validator: (value) => (value == null || value.length < 8)
                ? 'Password must be at least 8 characters long.'
                : null,
          ),
          const SizedBox(height: 18),

          // Confirm Password
          _buildTextField(
            controller: _confirmPasswordController,
            label: 'Confirm Password',
            hint: 'Re-enter your password',
            icon: Icons.lock_clock_outlined,
            obscureText: true,
            enabled: !isSubmitting,
            validator: (value) =>
                (value == null || value.isEmpty) ? 'Please confirm password.' : null,
          ),
          const SizedBox(height: 32),

          // Submit / Next Step Button
          FilledButton(
            onPressed: isSubmitting ? null : _nextStep,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              _role == RegisterableRole.seeker
                  ? 'Create Account'
                  : 'Next: Select Subscription Plan →',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 20),

          Center(
            child: TextButton(
              onPressed: isSubmitting ? null : () => context.go('/login'),
              child: RichText(
                text: TextSpan(
                  text: 'Already have an account? ',
                  style: const TextStyle(color: AppColors.inkMuted, fontSize: 14),
                  children: const [
                    TextSpan(
                      text: 'Sign In',
                      style: TextStyle(
                        color: AppColors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2: Subscription Plans Selection Cards (Employer & Agency)
  // ---------------------------------------------------------------------------

  Widget _buildStep2SubscriptionPlans(BuildContext context, bool isSubmitting) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Select a plan for your business account. You will be redirected to Chapa to complete payment.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.inkMuted, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 28),

        // Plan 1: Basic
        _SubscriptionPlanCard(
          title: 'Basic Plan',
          price: 'ETB 5 / mo',
          description: 'Essential tools for small businesses looking for quick hires.',
          isPopular: false,
          isSelected: _selectedSubscriptionTier == 'basic',
          advantages: const [
            'Post up to 3 active jobs',
            'Standard candidate search access',
            'Email notifications on application',
            'Standard support response time',
          ],
          onSelect: () => setState(() => _selectedSubscriptionTier = 'basic'),
        ),
        const SizedBox(height: 16),

        // Plan 2: Premium (Featured)
        _SubscriptionPlanCard(
          title: 'Premium Plan',
          price: 'ETB 5 / mo',
          description: 'Ideal for growing companies needing high-priority matches.',
          isPopular: true,
          isSelected: _selectedSubscriptionTier == 'premium',
          advantages: const [
            'Post up to 15 active jobs',
            'Featured job badge on listings',
            'AI-powered smart candidate matching',
            'Direct messaging & chat with candidates',
            'Priority 24/7 customer support',
          ],
          onSelect: () => setState(() => _selectedSubscriptionTier = 'premium'),
        ),
        const SizedBox(height: 16),

        // Plan 3: Enterprise
        _SubscriptionPlanCard(
          title: 'Enterprise Plan',
          price: 'ETB 5 / mo',
          description: 'Unlimited capacity for large enterprises and recruitment agencies.',
          isPopular: false,
          isSelected: _selectedSubscriptionTier == 'enterprise',
          advantages: const [
            'Unlimited active job posts',
            'Full database search & CV exports',
            'Dedicated account manager',
            'ATS Integration & placement tracking',
            'Verified business badge & top listing spot',
          ],
          onSelect: () => setState(() => _selectedSubscriptionTier = 'enterprise'),
        ),
        const SizedBox(height: 32),

        FilledButton(
          onPressed: isSubmitting ? null : _submit,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: isSubmitting
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  'Pay via Chapa & Register (${_selectedSubscriptionTier.toUpperCase()})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Role Specific Fields Generator
  // ---------------------------------------------------------------------------

  List<Widget> _roleSpecificFields(bool isSubmitting) {
    switch (_role) {
      case RegisterableRole.seeker:
        return [
          _buildTextField(
            controller: _fullNameController,
            label: 'Full Name',
            hint: 'Abebe Kebede',
            icon: Icons.person_outline,
            enabled: !isSubmitting,
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Full name is required.'
                : null,
          ),
          const SizedBox(height: 18),
        ];
      case RegisterableRole.employer:
        return [
          _buildTextField(
            controller: _companyNameController,
            label: 'Company Name',
            hint: 'Kezera Trading PLC',
            icon: Icons.business_outlined,
            enabled: !isSubmitting,
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Company name is required.'
                : null,
          ),
          const SizedBox(height: 18),
          _buildTextField(
            controller: _tinNumberController,
            label: 'TIN Number',
            hint: '1002345678',
            icon: Icons.assignment_outlined,
            enabled: !isSubmitting,
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'TIN number is required.'
                : null,
          ),
          const SizedBox(height: 18),
        ];
      case RegisterableRole.agency:
        return [
          _buildTextField(
            controller: _agencyNameController,
            label: 'Agency Name',
            hint: 'Addis Talent Agency',
            icon: Icons.apartment_outlined,
            enabled: !isSubmitting,
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Agency name is required.'
                : null,
          ),
          const SizedBox(height: 18),
          _buildTextField(
            controller: _tinNumberController,
            label: 'TIN Number',
            hint: '1002345678',
            icon: Icons.assignment_outlined,
            enabled: !isSubmitting,
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'TIN number is required.'
                : null,
          ),
          const SizedBox(height: 18),
        ];
    }
  }

  // ---------------------------------------------------------------------------
  // Text Field Helper — leans on the shared InputDecorationTheme
  // (see AppTheme.light) for fill/border colors, same as login_screen.dart.
  // ---------------------------------------------------------------------------

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool enabled = true,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.ink, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.inkMuted, size: 20),
      ),
      validator: validator,
    );
  }
}

// ---------------------------------------------------------------------------
// Role Tab Helper
// ---------------------------------------------------------------------------

class _RoleTab extends StatelessWidget {
  const _RoleTab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.green : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : AppColors.inkMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.inkMuted,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Subscription Plan Card Component
// ---------------------------------------------------------------------------

class _SubscriptionPlanCard extends StatelessWidget {
  const _SubscriptionPlanCard({
    required this.title,
    required this.price,
    required this.description,
    required this.advantages,
    required this.isPopular,
    required this.isSelected,
    required this.onSelect,
  });

  final String title;
  final String price;
  final String description;
  final List<String> advantages;
  final bool isPopular;
  final bool isSelected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.greenSurface : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppColors.green : AppColors.border,
            width: isSelected ? 2.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isPopular)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'MOST POPULAR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Radio<bool>(
                  value: true,
                  groupValue: isSelected,
                  activeColor: AppColors.green,
                  onChanged: (_) => onSelect(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              price,
              style: const TextStyle(
                color: AppColors.greenDark,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                color: AppColors.inkMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            const Divider(color: AppColors.divider),
            const SizedBox(height: 10),
            ...advantages.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.green, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
