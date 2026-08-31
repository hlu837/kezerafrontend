import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/error/api_exception.dart';
import '../core/theme/app_theme.dart';
import '../features/ats/presentation/placement_chat_screen.dart'
    show atsRepositoryProvider;
import '../features/ats/domain/interview.dart';

/// Bottom sheet for rescheduling an interview or updating its status.
///
/// A note on how this maps to the actual backend, since it doesn't line up
/// 1:1 with a naive "status dropdown" reading:
///
/// * Interview mutations are keyed by the interview's own id, not the
///   placement id — a placement can have multiple interview rounds, so
///   [placementId] alone can't identify which one to update (see
///   `AtsRepository`'s doc comment). [interviewId] is required here for
///   that reason; [placementId] is kept because callers generally have it
///   handy and it's useful for logging/analytics, but it is NOT sent to
///   either endpoint.
/// * There is no `rescheduled` status on the backend (`InterviewStatus` is
///   only `scheduled` / `completed` / `cancelled` — see
///   `INTERVIEW_STATUS_TRANSITIONS`). Rescheduling is just moving the date
///   of a still-`scheduled` interview, not a status of its own. So the
///   dropdown here offers the three real statuses; picking "Scheduled"
///   with a changed date/time calls `rescheduleInterview`, picking
///   "Completed"/"Cancelled" calls `updateInterviewStatus`.
/// * `updateInterviewStatus` only accepts `completed`/`cancelled`
///   server-side, and it doesn't take notes — so when the user marks an
///   interview completed/cancelled, whatever they typed in the notes
///   field is not sent (the field is disabled in that state so that's not
///   silently swallowed).
class InterviewScheduleModal extends ConsumerStatefulWidget {
  const InterviewScheduleModal({
    super.key,
    required this.interviewId,
    required this.placementId,
    this.currentDate,
    this.status,
    this.currentNotes,
  });

  /// The interview being mutated. Required — see class doc.
  final String interviewId;

  /// Kept for context/display/analytics; not sent to the mutation
  /// endpoints themselves.
  final String placementId;

  /// Pre-fills the date/time pickers. Defaults to "now + 1 day" when
  /// omitted, since `rescheduleInterview` requires a future timestamp.
  final DateTime? currentDate;

  final InterviewStatus? status;

  final String? currentNotes;

  /// Convenience launcher. Returns `true` if an update was submitted
  /// successfully, `null`/`false` otherwise.
  static Future<bool?> show(
    BuildContext context, {
    required String interviewId,
    required String placementId,
    DateTime? currentDate,
    InterviewStatus? status,
    String? currentNotes,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InterviewScheduleModal(
        interviewId: interviewId,
        placementId: placementId,
        currentDate: currentDate,
        status: status,
        currentNotes: currentNotes,
      ),
    );
  }

  @override
  ConsumerState<InterviewScheduleModal> createState() =>
      _InterviewScheduleModalState();
}

class _InterviewScheduleModalState
    extends ConsumerState<InterviewScheduleModal> {
  late DateTime _date;
  late TimeOfDay _time;
  late InterviewStatus _status;
  late final TextEditingController _notesController;

  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial =
        widget.currentDate?.toLocal() ?? DateTime.now().add(const Duration(days: 1));
    _date = DateTime(initial.year, initial.month, initial.day);
    _time = TimeOfDay(hour: initial.hour, minute: initial.minute);
    _status = widget.status ?? InterviewStatus.scheduled;
    _notesController = TextEditingController(text: widget.currentNotes ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  DateTime get _combinedDateTime =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  bool get _dateTimeFieldsEnabled => _status == InterviewStatus.scheduled;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final repo = ref.read(atsRepositoryProvider);
      final notes = _notesController.text.trim();

      if (_status == InterviewStatus.completed ||
          _status == InterviewStatus.cancelled) {
        // Status-only transition — no date/notes on this endpoint.
        await repo.updateInterviewStatus(widget.interviewId, _status);
      } else {
        // Staying "scheduled" — treat this as a reschedule. At least one
        // field is required by the backend; date/time is always present.
        await repo.rescheduleInterview(
          widget.interviewId,
          scheduledFor: _combinedDateTime,
          notes: notes.isEmpty ? null : notes,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Text('Schedule Interview', style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  _dateTimeFieldsEnabled
                      ? 'Pick a date and time, or update the status below.'
                      : 'Date/time only apply while the interview is scheduled.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.inkMuted),
                ),
                const SizedBox(height: 20),
                const _FieldLabel('Status'),
                const SizedBox(height: 6),
                DropdownButtonFormField<InterviewStatus>(
                  initialValue: _status,
                  items: InterviewStatus.values
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(_statusLabel(status)),
                        ),
                      )
                      .toList(),
                  onChanged: _submitting
                      ? null
                      : (value) {
                          if (value != null) setState(() => _status = value);
                        },
                  decoration: const InputDecoration(isDense: true),
                ),
                const SizedBox(height: 16),
                const _FieldLabel('Date'),
                const SizedBox(height: 6),
                _PickerTile(
                  icon: Icons.calendar_today_outlined,
                  label: _formatDate(_date),
                  enabled: _dateTimeFieldsEnabled && !_submitting,
                  onTap: _pickDate,
                ),
                const SizedBox(height: 16),
                const _FieldLabel('Time'),
                const SizedBox(height: 6),
                _PickerTile(
                  icon: Icons.access_time,
                  label: _time.format(context),
                  enabled: _dateTimeFieldsEnabled && !_submitting,
                  onTap: _pickTime,
                ),
                const SizedBox(height: 16),
                _FieldLabel(
                  _dateTimeFieldsEnabled ? 'Notes (optional)' : 'Notes',
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _notesController,
                  enabled: _dateTimeFieldsEnabled && !_submitting,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 2000,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: _dateTimeFieldsEnabled
                        ? 'Reason for rescheduling, meeting link, etc.'
                        : 'Not sent when marking completed/cancelled',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.error),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text('Submit'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _statusLabel(InterviewStatus status) {
    switch (status) {
      case InterviewStatus.scheduled:
        return 'Scheduled';
      case InterviewStatus.completed:
        return 'Completed';
      case InterviewStatus.cancelled:
        return 'Cancelled';
    }
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .labelMedium
          ?.copyWith(color: AppColors.inkMuted),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
          color: enabled ? AppColors.surface : AppColors.background,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: enabled ? AppColors.inkMuted : AppColors.inkFaint,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: enabled ? AppColors.ink : AppColors.inkFaint,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// No `intl` dependency in this project — hand-rolled to match the
/// convention already used in `placement_chat_screen.dart`.
String _formatDate(DateTime date) =>
    '${_months[date.month - 1]} ${date.day}, ${date.year}';
