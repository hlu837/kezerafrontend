import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/api_exception.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../jobs/domain/job.dart';
import '../../jobs/presentation/job_detail_screen.dart';
import '../domain/agency_comment.dart';
import 'agency_comments_provider.dart';

/// Applying is a seeker-only action (see `JobApplyButton`'s CV-required
/// apply flow, which assumes a seeker's own profile). A guest gets sent
/// to sign up; anyone signed in as something other than a seeker (this
/// agency itself, an employer, an admin) just gets told applying isn't
/// available to them, rather than the button silently 404ing.
void _promptApply(BuildContext context, bool isAuthenticated) {
  if (!isAuthenticated) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Create a free account to apply for jobs.')),
    );
    context.go('/register');
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Only job seekers can apply for jobs.')),
    );
  }
}

/// An agency's public profile — bio/logo/name plus the comment feed
/// anyone can read, and (if logged in as anything other than this same
/// agency) post to. Reached from `JobDetailScreen` by tapping an
/// agency poster's name/row.
class AgencyProfileScreen extends ConsumerWidget {
  const AgencyProfileScreen({
    super.key,
    required this.agencyId,
    required this.agencyName,
  });

  /// The agency's User id — see `AgencyComment.model.js`'s note on why
  /// this doubles as the comments' `agencyId`.
  final String agencyId;

  /// Shown immediately as the app bar title/heading while the full
  /// public profile loads, so the screen doesn't open blank.
  final String agencyName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(agencyPublicProfileProvider(agencyId));
    final commentsAsync = ref.watch(agencyCommentsProvider(agencyId));
    final authState = ref.watch(authProvider);

    final currentUser = authState.user;
    // An agency can read its own profile page like anyone else, but
    // may not add a comment to it — mirrors the backend's own check in
    // agencyComment.service.js#createComment.
    final canComment = authState.isAuthenticated &&
        !(currentUser!.role.name == 'agency' && currentUser.id == agencyId);

    return Scaffold(
      appBar: AppBar(title: Text(agencyName)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            profileAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  error is ApiException ? error.message : 'Could not load this agency.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              data: (profile) => _ProfileHeader(profile: profile),
            ),
            const Divider(height: 32),
            _JobsSection(
              agencyId: agencyId,
              isSeeker: authState.isAuthenticated &&
                  currentUser!.role.name == 'seeker',
              isAuthenticated: authState.isAuthenticated,
            ),
            const Divider(height: 32),
            _CommentsSection(
              agencyId: agencyId,
              commentsAsync: commentsAsync,
              canComment: canComment,
              isLoggedOut: !authState.isAuthenticated,
              currentUserId: currentUser?.id,
              isAdmin: currentUser?.role.name == 'admin',
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final AgencyPublicProfile profile;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundImage: profile.logoUrl != null && profile.logoUrl!.isNotEmpty
              ? NetworkImage(profile.logoUrl!)
              : null,
          child: profile.logoUrl == null || profile.logoUrl!.isEmpty
              ? const Icon(Icons.groups_outlined, size: 28)
              : null,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(profile.agencyName, style: Theme.of(context).textTheme.titleLarge),
              if (profile.operationalCity != null && profile.operationalCity!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: outline),
                    const SizedBox(width: 4),
                    Text(
                      profile.operationalCity!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: outline),
                    ),
                  ],
                ),
              ],
              if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(profile.bio!, style: Theme.of(context).textTheme.bodyMedium),
              ],
              if (profile.candidateCount > 0 || profile.yearsInBusiness != null) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (profile.candidateCount > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.groups_outlined, size: 16, color: outline),
                          const SizedBox(width: 4),
                          Text(
                            '${profile.candidateCount} '
                            '${profile.candidateCount == 1 ? 'candidate' : 'candidates'}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: outline),
                          ),
                        ],
                      ),
                    if (profile.yearsInBusiness != null && profile.yearsInBusiness! > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 16, color: outline),
                          const SizedBox(width: 4),
                          Text(
                            '${profile.yearsInBusiness} '
                            '${profile.yearsInBusiness == 1 ? 'year' : 'years'} in business',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: outline),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// "Jobs" list on an agency's public profile — GET /agencies/:agencyId
/// /jobs, every open posting from this agency. Mirrors
/// `_CommentsSection`'s placement (its own titled block, straight
/// after the profile header) but stays read-only — unlike comments,
/// nothing here is posted/deleted in place, so a plain `FutureProvider`
/// (via `agencyJobsProvider`) is enough.
class _JobsSection extends ConsumerWidget {
  const _JobsSection({
    required this.agencyId,
    required this.isSeeker,
    required this.isAuthenticated,
  });

  final String agencyId;
  final bool isSeeker;
  final bool isAuthenticated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outline = Theme.of(context).colorScheme.outline;
    final jobsAsync = ref.watch(agencyJobsProvider(agencyId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Jobs', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(width: 8),
            jobsAsync.maybeWhen(
              data: (result) => Text(
                '${result.count} open',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: outline),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        jobsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Text(
            error is ApiException ? error.message : 'Could not load this agency\'s jobs.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          data: (result) {
            if (result.jobs.isEmpty) {
              return Text(
                'No open jobs from this agency right now.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: outline),
              );
            }
            return Column(
              children: [
                for (final job in result.jobs)
                  _JobRow(
                    job: job,
                    isGuest: !isSeeker,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => JobDetailScreen(
                          job: job,
                          isGuest: !isSeeker,
                          applied: false,
                          onApply: !isSeeker
                              ? (_) => _promptApply(context, isAuthenticated)
                              : null,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _JobRow extends StatelessWidget {
  const _JobRow({required this.job, required this.isGuest, required this.onTap});

  final Job job;
  final bool isGuest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${job.jobType.wireValue} · ${job.location}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: outline),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: outline),
          ],
        ),
      ),
    );
  }
}

class _CommentsSection extends ConsumerStatefulWidget {
  const _CommentsSection({
    required this.agencyId,
    required this.commentsAsync,
    required this.canComment,
    required this.isLoggedOut,
    required this.currentUserId,
    required this.isAdmin,
  });

  final String agencyId;
  final AsyncValue<AgencyCommentsPage> commentsAsync;
  final bool canComment;
  final bool isLoggedOut;
  final String? currentUserId;
  final bool isAdmin;

  @override
  ConsumerState<_CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends ConsumerState<_CommentsSection> {
  final _controller = TextEditingController();
  int? _rating;
  bool _submitting = false;
  String? _submitError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final body = _controller.text.trim();
    if (body.isEmpty) return;

    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      await ref
          .read(agencyCommentsProvider(widget.agencyId).notifier)
          .addComment(body: body, rating: _rating);
      _controller.clear();
      setState(() => _rating = null);
    } on ApiException catch (e) {
      setState(() => _submitError = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _confirmDelete(String commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text('This removes your comment from this agency\'s profile.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(agencyCommentsProvider(widget.agencyId).notifier).deleteComment(commentId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Comments', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(width: 8),
            widget.commentsAsync.maybeWhen(
              data: (page) => page.averageRating != null
                  ? Row(
                      children: [
                        const Icon(Icons.star, size: 16, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(
                          '${page.averageRating} · ${page.total} comment${page.total == 1 ? '' : 's'}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: outline),
                        ),
                      ],
                    )
                  : Text(
                      '${page.total} comment${page.total == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: outline),
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.canComment) _CommentComposer(this),
        if (widget.isLoggedOut) ...[
          const SizedBox(height: 4),
          Text(
            'Log in to leave a comment on this agency.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: outline),
          ),
        ],
        const SizedBox(height: 16),
        widget.commentsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Text(
            error is ApiException ? error.message : 'Could not load comments.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          data: (page) {
            if (page.comments.isEmpty) {
              return Text(
                'No comments yet. Be the first to share your experience.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: outline),
              );
            }
            return Column(
              children: [
                for (final comment in page.comments)
                  _CommentTile(
                    comment: comment,
                    canDelete: widget.isAdmin || comment.authorId == widget.currentUserId,
                    onDelete: () => _confirmDelete(comment.id),
                  ),
                if (page.hasMore)
                  TextButton(
                    onPressed: () =>
                        ref.read(agencyCommentsProvider(widget.agencyId).notifier).loadMore(),
                    child: const Text('Load more'),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Small helper so [_CommentComposer] can reach back into
/// [_CommentsSectionState]'s controller/submit logic without
/// duplicating its state.
class _CommentComposer extends StatelessWidget {
  const _CommentComposer(this.state);

  final _CommentsSectionState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var star = 1; star <= 5; star++)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  (state._rating ?? 0) >= star ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                ),
                onPressed: () => state.setState(
                  () => state._rating = state._rating == star ? null : star,
                ),
              ),
          ],
        ),
        TextField(
          controller: state._controller,
          maxLines: 3,
          maxLength: 1000,
          decoration: const InputDecoration(
            hintText: 'Share your experience with this agency…',
            border: OutlineInputBorder(),
          ),
        ),
        if (state._submitError != null) ...[
          Text(
            state._submitError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 4),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: state._submitting ? null : state._submit,
            child: state._submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Post comment'),
          ),
        ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.canDelete,
    required this.onDelete,
  });

  final AgencyComment comment;
  final bool canDelete;
  final VoidCallback onDelete;

  String _relativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  comment.authorName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (comment.rating != null) ...[
                Icon(Icons.star, size: 14, color: Colors.amber),
                const SizedBox(width: 2),
                Text('${comment.rating}', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(width: 8),
              ],
              Text(
                _relativeTime(comment.createdAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: outline),
              ),
              if (canDelete)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  tooltip: 'Delete comment',
                  onPressed: onDelete,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(comment.body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
