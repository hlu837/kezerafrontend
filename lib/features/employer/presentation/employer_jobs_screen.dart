import 'package:flutter/material.dart';

import '../../jobs/presentation/my_jobs_board.dart';

/// The employer's own job postings list — open/closed toggle per job,
/// "View candidates"/"Edit" actions, and a shortcut into the posting
/// form. Reached from `EmployerDashboardScreen`'s "Total Jobs Posted"
/// card / "View all job postings" link rather than being the dashboard
/// itself, since the dashboard is now a reporting overview (job/
/// applicant counts) and this is the underlying list those counts
/// summarize. Shares [MyJobsBoard] with `AgencyDashboardScreen` — see
/// that widget's doc comment.
class EmployerJobsScreen extends StatelessWidget {
  const EmployerJobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MyJobsBoard(
      newJobPath: '/employer/jobs/new',
      editJobPath: '/employer/jobs/edit',
    );
  }
}
