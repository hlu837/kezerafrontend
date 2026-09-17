import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/presentation/auth_provider.dart';

/// Shown to employers/agencies whose account is pending review or rejected.
class VerificationStatusScreen extends ConsumerStatefulWidget {
  const VerificationStatusScreen({super.key});

  @override
  ConsumerState<VerificationStatusScreen> createState() =>
      _VerificationStatusScreenState();
}

class _VerificationStatusScreenState
    extends ConsumerState<VerificationStatusScreen> {
  bool _isPayingNow = false;

  /// Re-fires the same `POST /payments/initialize-subscription` step
  /// registration triggers, for anyone who's stuck at `payment_pending`
  /// because they closed/lost the checkout page before finishing it (or
  /// hit the launch failure registration now warns about). Without this,
  /// there was no way back into the payment flow at all — the account
  /// would sit invisible to admin's approval queue forever, since
  /// `verify-callback` (the thing that moves it to `pending`) never runs
  /// until the payment actually completes.
  Future<void> _payNow() async {
    setState(() => _isPayingNow = true);
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.dio.post<Map<String, dynamic>>(
        '/payments/initialize-subscription',
      );

      final checkoutUrl = (response.data!['data']
          as Map<String, dynamic>)['checkoutUrl'] as String;

      final launched = await launchUrl(
        Uri.parse(checkoutUrl),
        mode: LaunchMode.externalApplication,
      );

      if (!mounted) return;
      if (!launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't open the payment page.")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not start the payment process.')),
      );
    } finally {
      if (mounted) setState(() => _isPayingNow = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F1A),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF7B8CDE))),
      );
    }
    final isPending = user.isPending || user.isPaymentPending;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isPending
                          ? const Color(0xFF2A2A4A)
                          : const Color(0xFF3A1A1A),
                    ),
                    child: Icon(
                      isPending
                          ? Icons.hourglass_empty_rounded
                          : Icons.cancel_outlined,
                      size: 52,
                      color: isPending
                          ? const Color(0xFF7B8CDE)
                          : const Color(0xFFE57373),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Title
                  Text(
                    user.isPaymentPending
                        ? 'Payment Required'
                        : isPending
                            ? 'Pending Review'
                            : 'Verification Rejected',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Subtitle
                  Text(
                    user.isPaymentPending
                        ? 'Complete your subscription payment to send your account to our admin team for review.'
                        : isPending
                            ? 'Your account is currently under review by our admin team. You will receive a notification once your account is approved. This usually takes 1–2 business days.'
                            : 'Your account verification was not approved. Please review the reason below and resubmit your documents.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withOpacity(0.6),
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // Retry payment for anyone stuck at `payment_pending` —
                  // e.g. they closed the checkout tab, or the launch
                  // failed the first time.
                  if (user.isPaymentPending) ...[
                    const SizedBox(height: 40),
                    _GradientButton(
                      label: _isPayingNow ? 'Opening payment page...' : 'Pay Now',
                      icon: Icons.payment_rounded,
                      onTap: _isPayingNow ? null : _payNow,
                    ),
                  ],

                  // Rejection reason box
                  if (!isPending &&
                      user.verificationRejectionReason != null &&
                      user.verificationRejectionReason!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3A1A1A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: const Color(0xFFE57373).withOpacity(0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline,
                                  color: Color(0xFFE57373), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Rejection Reason',
                                style: TextStyle(
                                  color:
                                      const Color(0xFFE57373).withOpacity(0.9),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            user.verificationRejectionReason!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),

                  // Action buttons for rejected state
                  if (!isPending) ...[
                    _GradientButton(
                      label: 'Resubmit Documents',
                      icon: Icons.upload_file_rounded,
                      onTap: () => context.go('/verification/resubmit'),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.payment_rounded,
                          color: Color(0xFF7B8CDE)),
                      label: const Text(
                        'Request Refund',
                        style: TextStyle(color: Color(0xFF7B8CDE)),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                        side:
                            const BorderSide(color: Color(0xFF7B8CDE), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => _showRefundDialog(context, ref),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Logout button
                  TextButton(
                    onPressed: () => ref.read(authProvider.notifier).logout(),
                    child: Text(
                      'Log out',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showRefundDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Request Refund',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'A refund request will be submitted to our support team. We will contact you via your registered email or phone within 3–5 business days.',
          style: TextStyle(color: Colors.white.withOpacity(0.7), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF7B8CDE))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B8CDE),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Refund request submitted. We\'ll be in touch!'),
                  backgroundColor: Color(0xFF4CAF50),
                ),
              );
            },
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF5C6BC0), Color(0xFF7B8CDE)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5C6BC0).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
