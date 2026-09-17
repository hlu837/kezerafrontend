import 'package:flutter/material.dart';

import '../../jobs/presentation/my_jobs_board.dart';

/// The agency's own job postings — same list, same "Post a job"/"Edit"/
/// open-closed-toggle actions as `EmployerDashboardScreen`, since an
/// agency posts and manages jobs exactly like an employer does on the
/// backend (see `Job.creatorType`). Shares [MyJobsBoard] with the
/// employer dashboard rather than duplicating the list UI.
class AgencyDashboardScreen extends StatelessWidget {
  const AgencyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MyJobsBoard(
      newJobPath: '/agency/jobs/new',
      editJobPath: '/agency/jobs/edit',
    );
  }
}
