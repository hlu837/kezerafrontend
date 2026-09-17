import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../domain/agency_finance.dart';
import 'agency_provider.dart';

/// "Manage commission" — the agency-facing view over
/// `POST /agencies/finance/ledger` and `GET /agencies/dashboard/stats`:
/// today's KPIs and revenue breakdown, the running ledger balance, and
/// a form to log a new registration-fee or commission entry. Backed by
/// `agencyFinanceProvider`.
class AgencyCommissionScreen extends ConsumerWidget {
  const AgencyCommissionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(agencyFinanceProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(agencyFinanceProvider.notifier).load(),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Manage commission', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Log registration fees and placement commissions, and track '
            'today\'s revenue against your running balance.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
          const SizedBox(height: 24),
          state.stats.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                error is ApiException ? error.message : 'Could not load your stats.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            data: (stats) => _StatsSection(stats: stats),
          ),
          const SizedBox(height: 24),
          const _LedgerEntryForm(),
          if (state.recentEntries.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Logged this session', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (final entry in state.recentEntries)
                    _RecentEntryTile(entry: entry),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.stats});

  final AgencyDashboardStats stats;

  String _birr(double amount) => 'ETB ${amount.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _StatCard(
              label: 'Ledger balance',
              value: _birr(stats.ledgerBalance),
              icon: Icons.account_balance_wallet_outlined,
              emphasize: true,
            ),
            _StatCard(
              label: 'Registration fees today',
              value: _birr(stats.revenue.registrationFeesToday),
              icon: Icons.person_add_alt_outlined,
            ),
            _StatCard(
              label: 'Commissions today',
              value: _birr(stats.revenue.commissionsToday),
              icon: Icons.handshake_outlined,
            ),
            _StatCard(
              label: 'Net revenue today',
              value: _birr(stats.revenue.netRevenueToday),
              icon: Icons.trending_up_outlined,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 20,
          runSpacing: 8,
          children: [
            _MiniStat(label: 'Walk-ins registered today', value: stats.walkInsRegisteredToday),
            _MiniStat(label: 'Dispatches sent today', value: stats.dispatchesSentToday),
            _MiniStat(label: 'Successful placements today', value: stats.successfulPlacementsToday),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 220,
      child: Card(
        color: emphasize ? colorScheme.primaryContainer : null,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: emphasize ? colorScheme.onPrimaryContainer : colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: emphasize ? colorScheme.onPrimaryContainer : null,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: emphasize ? colorScheme.onPrimaryContainer : colorScheme.outline,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$value', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: outline)),
      ],
    );
  }
}

class _LedgerEntryForm extends ConsumerStatefulWidget {
  const _LedgerEntryForm();

  @override
  ConsumerState<_LedgerEntryForm> createState() => _LedgerEntryFormState();
}

class _LedgerEntryFormState extends ConsumerState<_LedgerEntryForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  LedgerTransactionType _type = LedgerTransactionType.commission;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(agencyFinanceProvider.notifier).recordEntry(
            LedgerEntryPayload(
              amount: double.parse(_amountController.text.trim()),
              transactionType: _type,
              description: _descriptionController.text.trim(),
            ),
          );
      _amountController.clear();
      _descriptionController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_type.label} logged.')),
        );
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Failed to log this entry.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Log a new entry', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              SegmentedButton<LedgerTransactionType>(
                segments: const [
                  ButtonSegment(
                    value: LedgerTransactionType.commission,
                    label: Text('Commission'),
                    icon: Icon(Icons.handshake_outlined),
                  ),
                  ButtonSegment(
                    value: LedgerTransactionType.registrationFee,
                    label: Text('Registration fee'),
                    icon: Icon(Icons.person_add_alt_outlined),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (selection) =>
                    setState(() => _type = selection.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount (ETB)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) return 'Enter an amount';
                  final parsed = double.tryParse(trimmed);
                  if (parsed == null || parsed <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'e.g. Commission for placing Abebe at ABC Trading',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 8),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Log entry'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentEntryTile extends StatelessWidget {
  const _RecentEntryTile({required this.entry});

  final AgencyLedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return ListTile(
      leading: Icon(
        entry.transactionType == LedgerTransactionType.commission
            ? Icons.handshake_outlined
            : Icons.person_add_alt_outlined,
      ),
      title: Text(entry.transactionType.label),
      subtitle: entry.description != null && entry.description!.isNotEmpty
          ? Text(entry.description!, maxLines: 2, overflow: TextOverflow.ellipsis)
          : null,
      trailing: Text(
        '+ETB ${entry.amount.toStringAsFixed(2)}',
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(fontWeight: FontWeight.w600, color: outline),
      ),
    );
  }
}
