import 'package:flutter/material.dart';

/// The app-wide "collapsible filter card" — an InkWell header (icon +
/// title + expand/collapse chevron) over an [AnimatedSize]-animated body,
/// inside a [Card]. Extracted from what was previously identical,
/// copy-pasted code across `JobBoardScreen`, `CandidatesScreen`, and
/// `PublicCandidatesBoardScreen`'s own filter sections.
///
/// Deliberately not built on the framework's [ExpansionTile]: its
/// divider/ripple/arrow-rotation styling doesn't match this app's cards
/// cleanly (see `CandidatesScreen`'s original doc comment), so every
/// filter card in the app — including the agency roster's, which used to
/// be the one holdout on `ExpansionTile` — now shares this widget
/// instead.
///
/// The caller owns the expanded/collapsed bit (usually a simple `bool`
/// field flipped via [onToggle]) rather than this widget managing its
/// own state, so a screen can reset or default the filters' visibility
/// alongside its other filter state.
class FilterCard extends StatelessWidget {
  const FilterCard({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.children,
    this.title = 'Filters',
    this.icon = Icons.tune_rounded,
    this.footer,
  });

  /// Whether the filter fields are currently shown.
  final bool expanded;

  /// Called when the header row is tapped — the caller flips its own
  /// `expanded` bool (typically via `setState`) in response.
  final VoidCallback onToggle;

  /// The header label. Every current screen just uses the default
  /// ("Filters"), but this is here for anywhere that wants to be more
  /// specific.
  final String title;

  /// The header's leading icon.
  final IconData icon;

  /// The filter fields themselves (text fields, dropdowns, chips, ...).
  /// Shown/hidden together as [expanded] changes, each preceded by the
  /// same 12px gap the original per-screen implementations used.
  final List<Widget> children;

  /// Optional content shown below the filter fields, outside the
  /// collapsible region — e.g. a "Search" button row. Stays visible
  /// even while collapsed, since hiding the only way to run a search
  /// behind a second tap isn't useful (this was previously a bug on the
  /// agency roster's `ExpansionTile`-based card, where the Search button
  /// lived inside the collapsible children and vanished along with the
  /// filters).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: colorScheme.outline),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    Icon(
                      expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: !expanded
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final child in children) ...[
                          const SizedBox(height: 12),
                          child,
                        ],
                      ],
                    ),
            ),
            if (footer != null) ...[
              const SizedBox(height: 14),
              footer!,
            ],
          ],
        ),
      ),
    );
  }
}
