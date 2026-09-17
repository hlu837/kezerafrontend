import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../seeker/domain/expert_trade_category.dart';
import '../domain/service_request.dart';
import 'service_requests_provider.dart';

/// Opens the "Request Service" form as a bottom sheet, targeting either a
/// specific Expert (a Seeker with a trade) or an Agency, found via the
/// nearby-experts/nearby-agencies map. Returns `true` if the request was
/// submitted, `null`/`false` if the sheet was dismissed without one —
/// callers show their own confirmation snackbar off that result so the
/// wording can mention the target's name.
Future<bool?> showRequestServiceSheet(
  BuildContext context, {
  required ServiceRequestTargetType targetType,
  required String targetId,
  String? initialCategory,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _RequestServiceForm(
      targetType: targetType,
      targetId: targetId,
      initialCategory: initialCategory,
    ),
  );
}

class _RequestServiceForm extends ConsumerStatefulWidget {
  const _RequestServiceForm({
    required this.targetType,
    required this.targetId,
    this.initialCategory,
  });

  final ServiceRequestTargetType targetType;
  final String targetId;
  final String? initialCategory;

  @override
  ConsumerState<_RequestServiceForm> createState() => _RequestServiceFormState();
}

class _RequestServiceFormState extends ConsumerState<_RequestServiceForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _budgetController = TextEditingController();

  late String? _category = widget.initialCategory;
  DateTime? _preferredDate;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _preferredDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _preferredDate = picked);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_category == null) {
      setState(() => _error = 'Pick a category for this request.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final payload = CreateServiceRequestPayload(
      targetType: widget.targetType,
      targetSeekerId: widget.targetType == ServiceRequestTargetType.seeker ? widget.targetId : null,
      targetTechnicianId:
          widget.targetType == ServiceRequestTargetType.technician ? widget.targetId : null,
      targetAgencyId: widget.targetType == ServiceRequestTargetType.agency ? widget.targetId : null,
      category: _category!,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      location: _locationController.text.trim(),
      preferredDate: _preferredDate,
      budget: _budgetController.text.trim().isEmpty ? null : _budgetController.text.trim(),
    );

    try {
      await ref.read(serviceRequestsRepositoryProvider).createServiceRequest(payload);
      ref.invalidate(myServiceRequestsProvider);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Keeps the form above the keyboard/nav bar regardless of how far
      // down the sheet the field being edited sits.
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
              Text(
                'Request a service',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Describe the job — they\'ll see this in their requests inbox.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final trade in kExpertTradeCategories)
                    DropdownMenuItem(value: trade.key, child: Text(trade.label)),
                ],
                onChanged: (value) => setState(() => _category = value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g. Fix a leaking kitchen tap',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value == null || value.trim().length < 3)
                    ? 'Enter at least 3 characters'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'What needs doing, and anything they should know beforehand',
                  border: OutlineInputBorder(),
                ),
                minLines: 3,
                maxLines: 5,
                validator: (value) => (value == null || value.trim().length < 10)
                    ? 'Enter at least 10 characters'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Job site location',
                  hintText: 'e.g. Bole, behind Edna Mall',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value == null || value.trim().length < 3)
                    ? 'Enter at least 3 characters'
                    : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.event_outlined, size: 18),
                      label: Text(
                        _preferredDate == null
                            ? 'Preferred date (optional)'
                            : '${_preferredDate!.year}-${_preferredDate!.month.toString().padLeft(2, '0')}-${_preferredDate!.day.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ),
                  if (_preferredDate != null)
                    IconButton(
                      tooltip: 'Clear date',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _preferredDate = null),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _budgetController,
                decoration: const InputDecoration(
                  labelText: 'Budget (optional)',
                  hintText: 'e.g. 800-1200 birr',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send request'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
