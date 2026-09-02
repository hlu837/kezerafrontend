import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/seeker.dart';
import 'availability_badge.dart';

/// Full profile view for a single candidate, reached by tapping "Details"
/// on a row in `CandidatesScreen`. Deliberately takes the already-fetched
/// [Seeker] straight from the search result via constructor (no
/// `GET /seekers/:id` round trip) — search already returns every public
/// field this screen shows, so there's nothing more to fetch.
class CandidateDetailScreen extends StatelessWidget {
  const CandidateDetailScreen({super.key, required this.seeker});

  final Seeker seeker;

  Future<void> _openCv(BuildContext context) async {
    final cvUrl = seeker.cvUrl;
    if (cvUrl == null) return;
    await launchUrl(Uri.parse(cvUrl), mode: LaunchMode.externalApplication);
  }

  String _initials(String fullName) {
    final parts =
        fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final outline = colorScheme.outline;
    final photoUrl = seeker.photoUrl;

    return Scaffold(
      appBar: AppBar(title: const Text('Candidate profile')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: colorScheme.primaryContainer,
                backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                child: photoUrl == null
                    ? Text(
                        _initials(seeker.fullName),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          seeker.fullName,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        AvailabilityBadgeWidget(
                          available: seeker.availabilityStatus,
                        ),
                        if (seeker.isBoosted)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.greenSurface,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.rocket_launch,
                                    size: 11, color: AppColors.greenDark),
                                const SizedBox(width: 3),
                                Text(
                                  'Boosted',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.greenDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _IconLine(
                      icon: Icons.place_outlined,
                      text: seeker.city ?? 'City not specified',
                      color: outline,
                    ),
                    if (seeker.experienceLevel != null) ...[
                      const SizedBox(height: 2),
                      _IconLine(
                        icon: Icons.workspace_premium_outlined,
                        text: seeker.experienceLevel!.label,
                        color: outline,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (seeker.bio != null && seeker.bio!.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('About', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(seeker.bio!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          if (seeker.skills.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Skills', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final skill in seeker.skills)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(skill, style: const TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ],
          if (seeker.experience.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Experience', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final entry in seeker.experience)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      [
                        entry.company,
                        if (entry.location != null && entry.location!.isNotEmpty)
                          entry.location!,
                      ].join(' · '),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: outline),
                    ),
                    if (entry.startDate != null)
                      Text(
                        '${entry.startDate} – ${entry.current ? 'Present' : (entry.endDate ?? '')}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: outline),
                      ),
                  ],
                ),
              ),
          ],
          if (seeker.cvUrl != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _openCv(context),
              icon: const Icon(Icons.description_outlined),
              label: const Text('View CV'),
            ),
          ],
        ],
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
