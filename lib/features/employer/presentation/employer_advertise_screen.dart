import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/error/api_exception.dart';
import '../domain/ad.dart';
import 'ads_provider.dart';

/// Employer/agency screen to create, pay for, and track promoted ads —
/// the missing piece between the backend `/ads` + `/payments/initialize-ad`
/// endpoints and the public carousel (`ad_carousel.dart`'s `activeAdsProvider`)
/// that eventually shows them.
///
/// Reached from `EmployerAccountScreen`'s "Manage account" list rather
/// than a 6th bottom-nav slot — mirrors how "Edit profile" and
/// "Sign out" are already pushed from there instead of getting their
/// own destinations. Backend gates advertising per subscription tier
/// (`SubscriptionPlan.canAdvertise`, admin-controlled); a `403` from
/// `POST /ads` surfaces here as a plain error banner rather than this
/// screen trying to predict eligibility client-side.
class EmployerAdvertiseScreen extends ConsumerWidget {
  const EmployerAdvertiseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAds = ref.watch(myAdsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Advertise')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateAdSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New ad'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(myAdsProvider.notifier).load(),
        child: asyncAds.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorState(
            message: error is ApiException ? error.message : 'Could not load your ads.',
            onRetry: () => ref.read(myAdsProvider.notifier).load(),
          ),
          data: (ads) => ads.isEmpty
              ? const _EmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: ads.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _AdCard(ad: ads[i]),
                ),
        ),
      ),
    );
  }

  Future<void> _openCreateAdSheet(BuildContext context, WidgetRef ref) async {
    final ad = await showModalBottomSheet<Ad>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateAdSheet(),
    );
    if (ad == null || !context.mounted) return;

    // Straight into checkout — no reason to make the employer come
    // back and tap "Pay" separately right after creating the draft.
    await _launchAdCheckout(context, ref, ad.id);
  }
}

Future<void> _launchAdCheckout(BuildContext context, WidgetRef ref, String adId) async {
  try {
    final checkoutUrl = await ref.read(myAdsProvider.notifier).initiateAdPayment(adId);
    await launchUrl(Uri.parse(checkoutUrl), mode: LaunchMode.externalApplication);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Complete payment in the browser, then come back here — your ad will '
            'move to "Pending review" once payment is confirmed.',
          ),
        ),
      );
    }
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.campaign_outlined, size: 56, color: outline),
            const SizedBox(height: 16),
            Text(
              'No ads yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Promote your company, a service, or a product in the app\'s ad '
              'carousel. Tap "New ad" to get started.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _AdCard extends ConsumerWidget {
  const _AdCard({required this.ad});

  final Ad ad;

  Color _statusColor(BuildContext context, AdStatus status) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (status) {
      case AdStatus.active:
        return Colors.green;
      case AdStatus.pendingReview:
        return Colors.orange;
      case AdStatus.rejected:
        return colorScheme.error;
      case AdStatus.expired:
        return colorScheme.outline;
      case AdStatus.draft:
        return colorScheme.primary;
    }
  }

  String _formatDate(DateTime date) => '${date.month}/${date.day}/${date.year}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = _statusColor(context, ad.status);
    final canPay = ad.status == AdStatus.draft || ad.status == AdStatus.rejected;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  ad.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ad.status.label,
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(ad.subtitle, style: Theme.of(context).textTheme.bodyMedium),
          if (ad.status == AdStatus.active && ad.expiresAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Live until ${_formatDate(ad.expiresAt!)}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colorScheme.outline),
            ),
          ],
          if (ad.status == AdStatus.rejected && ad.rejectionReason != null) ...[
            const SizedBox(height: 8),
            Text(
              'Reason: ${ad.rejectionReason}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.error),
            ),
          ],
          if (canPay) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _launchAdCheckout(context, ref, ad.id),
                icon: const Icon(Icons.payment, size: 18),
                label: Text(ad.status == AdStatus.rejected ? 'Pay & resubmit' : 'Pay to submit'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bottom sheet form for POST /ads — title, subtitle, an icon choice
/// from the backend's fixed `AD_ICONS` enum, and an optional link.
/// Pops with the created [Ad] (still `draft`) so the caller can chain
/// straight into checkout.
class _CreateAdSheet extends ConsumerStatefulWidget {
  const _CreateAdSheet();

  @override
  ConsumerState<_CreateAdSheet> createState() => _CreateAdSheetState();
}

class _CreateAdSheetState extends ConsumerState<_CreateAdSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _linkController = TextEditingController();
  AdIcon _icon = AdIcon.campaign;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final ad = await ref.read(myAdsProvider.notifier).createAd(
            title: _titleController.text.trim(),
            subtitle: _subtitleController.text.trim(),
            icon: _icon,
            linkUrl: _linkController.text.trim().isEmpty ? null : _linkController.text.trim(),
          );
      if (mounted) Navigator.pop(context, ad);
    } on ApiException catch (e) {
      setState(() {
        _isSaving = false;
        _errorMessage = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('New ad', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Shown in the app\'s ad carousel once paid for and approved.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.outline),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title', counterText: ''),
                maxLength: 60,
                validator: (value) => (value == null || value.trim().length < 2)
                    ? 'Enter at least 2 characters'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _subtitleController,
                decoration: const InputDecoration(labelText: 'Subtitle', counterText: ''),
                maxLength: 140,
                maxLines: 2,
                validator: (value) => (value == null || value.trim().length < 2)
                    ? 'Enter at least 2 characters'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AdIcon>(
                value: _icon,
                decoration: const InputDecoration(labelText: 'Icon'),
                items: AdIcon.values
                    .map((icon) => DropdownMenuItem(value: icon, child: Text(icon.label)))
                    .toList(),
                onChanged: (value) => setState(() => _icon = value ?? AdIcon.campaign),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _linkController,
                decoration: const InputDecoration(
                  labelText: 'Link (optional)',
                  hintText: 'https://...',
                ),
                keyboardType: TextInputType.url,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  final uri = Uri.tryParse(value.trim());
                  return (uri != null && uri.hasScheme && uri.hasAuthority)
                      ? null
                      : 'Enter a valid URL';
                },
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create & continue to payment'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
