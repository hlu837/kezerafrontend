import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';

/// Public "Support" bottom-nav tab on the landing page
/// (public_job_board_screen.dart) — an explanatory summary of the
/// platform, a short FAQ, and how to reach the team (contact details
/// plus social links). There's no in-app ticketing/chat system, so
/// every action here just opens the device's mail/phone/browser via
/// url_launcher (already a dependency — see register_screen.dart's
/// Chapa checkout redirect for the existing usage pattern).
class PublicSupportScreen extends StatefulWidget {
  const PublicSupportScreen({super.key});

  @override
  State<PublicSupportScreen> createState() => _PublicSupportScreenState();
}

class _PublicSupportScreenState extends State<PublicSupportScreen> {
  // TODO(H): every value below (email, phone, WhatsApp, address, social
  // handles) is a placeholder in the existing
  // notifications@keferajobs.com / support@keferajobs.com pattern
  // (see backend-clean/.env.example NOTIFICATIONS_FROM_EMAIL) — swap
  // in the real contact channels and handles once they exist.
  static const _supportEmail = 'support@keferajobs.com';
  static const _supportPhoneDisplay = '+251 911 234 567';
  static const _supportPhoneDial = '+251911234567';
  static const _whatsappNumber = '251911234567'; // no leading '+' for wa.me
  static const _officeAddress = 'Bole Road, Addis Ababa, Ethiopia';

  static const _socialLinks = [
    (
      label: 'Facebook',
      icon: Icons.facebook,
      url: 'https://facebook.com/kazerajobs',
    ),
    (
      label: 'Telegram',
      icon: Icons.send_outlined,
      url: 'https://t.me/kazerajobs',
    ),
    (
      label: 'X (Twitter)',
      icon: Icons.alternate_email,
      url: 'https://x.com/kazerajobs',
    ),
    (
      label: 'LinkedIn',
      icon: Icons.business_center_outlined,
      url: 'https://linkedin.com/company/kazerajobs',
    ),
    (
      label: 'Instagram',
      icon: Icons.camera_alt_outlined,
      url: 'https://instagram.com/kazerajobs',
    ),
  ];

  static const _faqs = [
    (
      question: 'How do I apply for a job?',
      answer: 'Browse the Jobs tab, open a listing, and tap Apply. If '
          "you're not signed in yet, you'll be asked to create a free "
          'account first — applying itself is free.',
    ),
    (
      question: 'How do I post a job as an employer?',
      answer: 'Sign up as an Employer, complete business verification '
          '(TIN and business license) and choose a subscription plan. '
          'Once verified, you can post and manage jobs from your '
          'employer dashboard.',
    ),
    (
      question: 'How does agency partnership work?',
      answer: 'Register as an Agency and complete the same business '
          'verification as employers. Once approved, you can register '
          'candidates, submit them for open roles, and earn commission '
          'on placements. See the Agency tab for details.',
    ),
    (
      question: 'How do payments work?',
      answer: 'Subscription and verification payments are processed '
          'through Chapa. You\'ll be redirected to a secure checkout page '
          'to complete payment.',
    ),
    (
      question: 'I forgot my password — what do I do?',
      answer: 'There\'s currently no self-service password reset in the '
          'app. Contact support below with the phone number or email on '
          'your account and we\'ll help you regain access.',
    ),
    (
      question: 'Is my information secure?',
      answer: 'Your account is protected by a password you choose at '
          'sign-up, and payments are handled entirely by Chapa\'s secure '
          'checkout — we never see your card details.',
    ),
  ];

  /// Opens [uri] externally and surfaces a snackbar if nothing on the
  /// device could handle it — same launched-check as
  /// register_screen.dart's Chapa redirect, rather than failing silently.
  Future<void> _launch(Uri uri, {required String failureMessage}) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failureMessage)));
    }
  }

  Future<void> _emailSupport() => _launch(
        Uri(
          scheme: 'mailto',
          path: _supportEmail,
          query: 'subject=${Uri.encodeComponent('Kezera support request')}',
        ),
        failureMessage: 'Could not open a mail app.',
      );

  Future<void> _callSupport() => _launch(
        Uri(scheme: 'tel', path: _supportPhoneDial),
        failureMessage: 'Could not open the phone app.',
      );

  Future<void> _whatsappSupport() => _launch(
        Uri.parse('https://wa.me/$_whatsappNumber'),
        failureMessage: 'Could not open WhatsApp.',
      );

  Future<void> _openSocial(String url) => _launch(
        Uri.parse(url),
        failureMessage: 'Could not open that link.',
      );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.support_agent, color: AppColors.green, size: 40),
          const SizedBox(height: 16),
          Text(
            'Support & help',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Answers to common questions. Can\'t find what you need? '
            'Reach out below.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.inkMuted,
                ),
          ),
          const SizedBox(height: 24),
          _AboutKezeraSection(),
          const SizedBox(height: 28),
          Text(
            'Contact us',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Reach the Kezera team directly — usually within one business day.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.inkMuted,
                ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: AppColors.divider),
              child: Column(
                children: [
                  _ContactRow(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: _supportEmail,
                    onTap: _emailSupport,
                  ),
                  const Divider(height: 1),
                  _ContactRow(
                    icon: Icons.call_outlined,
                    label: 'Call',
                    value: _supportPhoneDisplay,
                    onTap: _callSupport,
                  ),
                  const Divider(height: 1),
                  _ContactRow(
                    icon: Icons.chat_outlined,
                    label: 'WhatsApp',
                    value: _supportPhoneDisplay,
                    onTap: _whatsappSupport,
                  ),
                  const Divider(height: 1),
                  _ContactRow(
                    icon: Icons.location_on_outlined,
                    label: 'Office',
                    value: _officeAddress,
                    // No app to open for a plain address — shown for
                    // reference only, unlike the tappable rows above.
                    onTap: null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Follow us',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final social in _socialLinks)
                OutlinedButton.icon(
                  onPressed: () => _openSocial(social.url),
                  icon: Icon(social.icon, size: 18),
                  label: Text(social.label),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.ink,
                    side: BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 28),
          // FAQ moved to the bottom of the page — the "Contact us" /
          // "Follow us" actions are what most visitors landing on this
          // tab actually want, so they no longer sit below a long
          // accordion.
          Text(
            'Frequently asked questions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: AppColors.divider),
              child: Column(
                children: [
                  for (var i = 0; i < _faqs.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        title: Text(
                          _faqs[i].question,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                        ),
                        iconColor: AppColors.green,
                        collapsedIconColor: AppColors.inkMuted,
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        expandedCrossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _faqs[i].answer,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.inkMuted,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Explanatory platform summary — what Kezera is and how the three
/// account types (seeker/employer/agency) fit together, for a visitor
/// landing on Support without context. Kept short and skimmable rather
/// than duplicating the full FAQ below it.
class _AboutKezeraSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.green, size: 20),
              const SizedBox(width: 8),
              Text(
                'About Kezera',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.ink,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Kezera is a job marketplace connecting job seekers, employers, '
            'and recruitment agencies across Ethiopia. Seekers browse and '
            'apply to open roles for free, or find nearby skilled experts '
            '(electricians, plumbers, and more) by location.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.inkMuted,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Employers and agencies complete business verification before '
            'posting jobs, and every subscription or verification payment '
            'is handled securely through Chapa. Agencies can also register '
            'walk-in candidates and earn commission on the placements they '
            'make — every account on the platform is reviewed by our team '
            'before it goes live.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.inkMuted,
                ),
          ),
        ],
      ),
    );
  }
}

/// One row in the "Contact us" card — icon, label, value, and (if
/// [onTap] is set) an affordance to actually reach out that way.
/// Mirrors `_JobRow`'s InkWell-row layout on `AgencyProfileScreen`.
class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.green),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.inkFaint,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right, size: 18, color: AppColors.inkFaint),
          ],
        ),
      ),
    );
  }
}
