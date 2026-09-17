import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'agency_candidates_screen.dart';
import 'agency_provider.dart';
import 'walk_in_registration_screen.dart';

/// "Registration" tab for the agency backoffice — combines the walk-in
/// registration form and the resulting roster into a single two-tab
/// screen: "Register" to add a new candidate, "Registered" to see
/// everyone registered so far (`AgencyCandidatesScreen`, backed by
/// `GET /agencies/candidates`).
///
/// Replaces the previous separate "Registration" and "Candidates" nav
/// items — registering and then checking who's been registered is one
/// workflow, so it lives on one page now.
class AgencyRegistrationScreen extends ConsumerStatefulWidget {
  const AgencyRegistrationScreen({super.key});

  @override
  ConsumerState<AgencyRegistrationScreen> createState() =>
      _AgencyRegistrationScreenState();
}

class _AgencyRegistrationScreenState
    extends ConsumerState<AgencyRegistrationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// After a successful registration: refresh the roster so the new
  /// candidate shows up immediately, then jump to the "Registered" tab.
  void _onRegistered() {
    ref.read(agencyRosterProvider.notifier).search();
    _tabController.animateTo(1);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Register', icon: Icon(Icons.person_add_alt_outlined)),
              Tab(text: 'Registered', icon: Icon(Icons.groups_outlined)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              WalkInRegistrationScreen(onRegistered: _onRegistered),
              const AgencyCandidatesScreen(),
            ],
          ),
        ),
      ],
    );
  }
}
