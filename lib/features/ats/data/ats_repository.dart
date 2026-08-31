import 'package:dio/dio.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/interview.dart';
import '../domain/message.dart';

/// Talks to the placement-scoped messaging endpoints and the id-keyed
/// interview mutation endpoints. Knows nothing about state management —
/// same shape as `JobsRepository`/`AuthRepository`, so callers only ever
/// deal with [ApiException] on failure.
///
/// Note on routing: messages are nested under the placement
/// (`/placements/:placementId/messages`), but interview reschedule/status
/// updates are NOT — the backend keys those by the interview's own id
/// (`/interviews/:id`, `/interviews/:id/status`; see
/// `interviews.routes.js` and `interviews.service.js`). A placement can
/// have multiple interview rounds, so `placementId` alone can't identify
/// which one to mutate.
class AtsRepository {
  AtsRepository(this._apiClient);

  final ApiClient _apiClient;

  /// GET /placements/:placementId/messages
  ///
  /// Full thread for the placement, oldest first. As a side effect, the
  /// backend marks every message from the *other* participant as read —
  /// there's no separate mark-as-read call.
  Future<List<Message>> getMessages(String placementId) => _guard(() async {
        final response = await _apiClient.dio.get<Map<String, dynamic>>(
          '/placements/$placementId/messages',
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return (data['messages'] as List<dynamic>)
            .map((json) => Message.fromJson(json as Map<String, dynamic>))
            .toList();
      });

  /// POST /placements/:placementId/messages
  ///
  /// [content] becomes the message `body` (1–5000 chars, trimmed
  /// server-side — see `sendMessageSchema`). `senderId`/`senderRole` are
  /// derived server-side from the authenticated caller and never sent.
  Future<Message> sendMessage(String placementId, String content) =>
      _guard(() async {
        final response = await _apiClient.dio.post<Map<String, dynamic>>(
          '/placements/$placementId/messages',
          data: {'body': content},
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return Message.fromJson(data['message'] as Map<String, dynamic>);
      });

  /// PATCH /interviews/:id
  ///
  /// Reschedules an already-`scheduled` interview in place (poster-only,
  /// enforced server-side). Partial update — pass only what changed; at
  /// least one of [scheduledFor]/[mode]/[location]/[notes] is required
  /// (`rescheduleInterviewSchema.min(1)`), and [scheduledFor] must still
  /// be in the future if provided.
  ///
  /// There's no dedicated "reason" field on the backend — if you need to
  /// record why it moved, fold that text into [notes].
  Future<Interview> rescheduleInterview(
    String interviewId, {
    DateTime? scheduledFor,
    InterviewMode? mode,
    String? location,
    String? notes,
  }) =>
      _guard(() async {
        assert(
          scheduledFor != null || mode != null || location != null || notes != null,
          'rescheduleInterview requires at least one field to update.',
        );
        final response = await _apiClient.dio.patch<Map<String, dynamic>>(
          '/interviews/$interviewId',
          data: {
            if (scheduledFor != null)
              'scheduled_for': scheduledFor.toIso8601String(),
            if (mode != null) 'mode': mode.wireValue,
            if (location != null) 'location': location,
            if (notes != null) 'notes': notes,
          },
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return Interview.fromJson(data['interview'] as Map<String, dynamic>);
      });

  /// PATCH /interviews/:id/status
  ///
  /// Marks an interview `completed` or `cancelled` (poster-only). The
  /// backend rejects any other target status (there's no manual path back
  /// to `scheduled` — see `INTERVIEW_STATUS_TRANSITIONS`).
  Future<Interview> updateInterviewStatus(
    String interviewId,
    InterviewStatus status,
  ) =>
      _guard(() async {
        assert(
          status == InterviewStatus.completed || status == InterviewStatus.cancelled,
          'updateInterviewStatus only accepts completed or cancelled.',
        );
        final response = await _apiClient.dio.patch<Map<String, dynamic>>(
          '/interviews/$interviewId/status',
          data: {'status': status.name},
        );
        final data = response.data!['data'] as Map<String, dynamic>;
        return Interview.fromJson(data['interview'] as Map<String, dynamic>);
      });

  /// Runs [action], converting any [DioException] into the [ApiException]
  /// [ApiClient]'s error interceptor already attached to it — same
  /// convention as `JobsRepository._guard`, so every repository method
  /// only ever throws [ApiException] on failure.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      final apiError = e.error;
      if (apiError is ApiException) throw apiError;
      throw ApiException(message: e.message ?? 'Something went wrong.');
    }
  }
}
