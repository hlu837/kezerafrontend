import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../agency/presentation/nearby_agencies_map_screen.dart';
import '../../seeker/presentation/nearby_experts_map_screen.dart';

/// Which side of the [NearbyMapScreen] toggle is active.
enum NearbyMapMode { experts, agencies }

/// Merges what used to be two separate routes/screens
/// (`NearbyExpertsMapScreen` at `/experts/nearby` and
/// `NearbyAgenciesMapScreen` at `/agencies/nearby`) into one map view
/// with a toggle, per the "dual-purpose map" platform spec. Both
/// `/experts/nearby` and `/agencies/nearby` (see app_router.dart) now
/// build this same screen, just with a different [initialMode] — once
/// here, switching modes is a tap on the toggle rather than a
/// navigation.
///
/// [NearbyExpertsMapScreen] and [NearbyAgenciesMapScreen] themselves no
/// longer own a Scaffold/AppBar — they're embedded here as the body for
/// whichever mode is selected, and this screen owns the single shared
/// Scaffold/AppBar plus the toggle. Switching modes swaps which one is
/// mounted (rather than keeping both alive via an IndexedStack), so
/// only one Gebeta map instance is ever live at a time — lighter on
/// memory/GPU, which matters more than preserving scroll/filter state
/// across a toggle that's expected to be occasional, not rapid.
class NearbyMapScreen extends StatefulWidget {
  const NearbyMapScreen({
    super.key,
    this.initialMode = NearbyMapMode.experts,
    this.initialTrade,
  });

  final NearbyMapMode initialMode;

  /// Only meaningful for [NearbyMapMode.experts] — passed straight
  /// through to `NearbyExpertsMapScreen.initialTrade` (see that
  /// class's doc comment). Ignored once the toggle is flipped to
  /// Agencies, and not restored if flipped back — a category picked on
  /// `/experts/categories` is a one-time entry filter, not a standing
  /// preference this screen needs to remember.
  final String? initialTrade;

  @override
  State<NearbyMapScreen> createState() => _NearbyMapScreenState();
}

class _NearbyMapScreenState extends State<NearbyMapScreen> {
  late NearbyMapMode _mode = widget.initialMode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _mode == NearbyMapMode.experts
              ? 'Find an expert near you'
              : 'Find agencies near you',
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _NearbyModeToggle(
                mode: _mode,
                onChanged: (mode) => setState(() => _mode = mode),
              ),
            ),
          ),
          Expanded(
            child: _mode == NearbyMapMode.experts
                ? NearbyExpertsMapScreen(initialTrade: widget.initialTrade)
                : const NearbyAgenciesMapScreen(),
          ),
        ],
      ),
    );
  }
}

/// "Experts / Agencies" segmented toggle for [NearbyMapScreen] — same
/// pill/segment visual language as `core/widgets/board_mode_toggle.dart`,
/// but that widget's `BoardMode` enum (Jobs vs Experts, for the guest
/// landing page) means something different from this screen's Experts
/// vs Agencies modes, so this is its own small toggle rather than a
/// reuse of that one.
class _NearbyModeToggle extends StatelessWidget {
  const _NearbyModeToggle({required this.mode, required this.onChanged});

  final NearbyMapMode mode;
  final ValueChanged<NearbyMapMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(context, label: 'Experts', value: NearbyMapMode.experts),
          _segment(context, label: 'Agencies', value: NearbyMapMode.agencies),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, {required String label, required NearbyMapMode value}) {
    final selected = mode == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.green : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected ? Colors.white : Theme.of(context).colorScheme.outline,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}
