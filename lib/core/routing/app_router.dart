import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/agency/presentation/agency_account_screen.dart';
import '../../features/agency/presentation/agency_dashboard_screen.dart';
import '../../features/agency/presentation/agency_shell.dart';
import '../../features/agency/presentation/placements_screen.dart';
import '../../features/agency/presentation/walk_in_registration_screen.dart';
import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../features/admin/presentation/admin_placeholder_screen.dart';
import '../../features/admin/presentation/admin_shell.dart';
import '../../features/admin/presentation/admin_verifications_screen.dart';
import '../../features/auth/domain/user_model.dart';
import '../../features/auth/presentation/auth_provider.dart';
import '../../features/auth/presentation/auth_state.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/verification_status_screen.dart';
import '../../features/employer/presentation/employer_dashboard_screen.dart';
import '../../features/employer/presentation/employer_messages_screen.dart';
import '../../features/employer/presentation/employer_shell.dart';
import '../../features/jobs/presentation/job_board_screen.dart';
import '../../features/jobs/presentation/post_job_screen.dart';
import '../../features/jobs/presentation/public_job_board_screen.dart';
import '../../features/seeker/presentation/candidates_screen.dart';
import '../../features/seeker/presentation/category_preferences_screen.dart';
import '../../features/seeker/presentation/cv_builder_screen.dart';
import '../../features/seeker/presentation/cv_choice_screen.dart';
import '../../features/seeker/presentation/my_applications_screen.dart';
import '../../features/seeker/presentation/seeker_account_screen.dart';
import '../../features/seeker/presentation/seeker_dashboard_screen.dart';
import '../../features/seeker/presentation/seeker_messages_screen.dart';
import '../../features/seeker/presentation/seeker_shell.dart';
import '../widgets/responsive_shell.dart';

/// Bridges Riverpod's [authProvider] to go_router's [refreshListenable].
///
/// go_router only re-evaluates [GoRouter.redirect] when this notifies, so
/// without it a login/logout wouldn't trigger a redirect until some other
/// navigation happened to occur.
class _AuthRouterRefresh extends ChangeNotifier {
  _AuthRouterRefresh(Ref ref) {
    ref.listen<AuthStatus>(
      authProvider.select((state) => state.status),
      (_, __) => notifyListeners(),
    );
  }
}

final _authRouterRefreshProvider = Provider<_AuthRouterRefresh>((ref) {
  return _AuthRouterRefresh(ref);
});

/// Every route that requires auth, grouped by the role allowed to see it,
/// with the [ShellNavItem]s + brand label used to build that role's shell.
/// Adding a new page to a role's section of the app means adding one entry
/// here (as a [GoRoute] under the matching branch below) — routing, the
/// role guard, and the nav sidebar/bottom-bar all stay in sync from this
/// single source of truth.
final Map<UserRole, String> _roleRoutePrefix = {
  UserRole.seeker: '/seeker',
  UserRole.employer: '/employer',
  UserRole.agency: '/agency',
  UserRole.admin: '/admin',
};

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(_authRouterRefreshProvider);

  return GoRouter(
    // '/jobs' is the logged-out landing page (public job board) — anyone
    // can land here and browse without an account; signing in/up is only
    // forced when they act on a listing (see PublicJobBoardScreen.onApply).
    initialLocation: '/jobs',
    refreshListenable: refresh,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final location = state.matchedLocation;
      // Routes anyone can reach logged-out; an already-authenticated user
      // hitting one of these gets bounced to their own dashboard instead
      // (same as the old login/register behavior below).
      const publicRoutes = {'/login', '/register', '/jobs'};
      const verificationRoutes = {'/verification-status'};
      final isGoingToPublicRoute = publicRoutes.contains(location);
      final isGoingToVerificationRoute = verificationRoutes.contains(location);

      switch (authState.status) {
        case AuthStatus.unknown:
          // Startup hydration in flight — root builder shows a splash, and
          // there's nothing safe to redirect to yet.
          return null;

        case AuthStatus.authenticating:
        case AuthStatus.unauthenticated:
          return isGoingToPublicRoute ? null : '/login';

        case AuthStatus.authenticated:
          final user = authState.user!;
          final role = user.role;
          final dashboardPath = role.dashboardPath;
          final allowedPrefix = _roleRoutePrefix[role]!;

          if (isGoingToPublicRoute) return dashboardPath;

          // Verification guard: pending/rejected employer or agency
          // must be shown the verification status screen.
          if ([UserRole.employer, UserRole.agency].contains(role) &&
              !user.isApproved) {
            // Allow them to stay on the verification page & admin dashboard
            if (isGoingToVerificationRoute ||
                location.startsWith('/admin')) {
              return null;
            }
            return '/verification-status';
          }

          // Route guard: a seeker hitting /employer/* (or vice versa) gets
          // bounced to their own dashboard instead of seeing someone
          // else's screen.
          if (!location.startsWith(allowedPrefix) &&
              !location.startsWith('/admin')) {
            return dashboardPath;
          }

          return null;
      }
    },
    routes: [
      // Public landing page — the job list, open to guests. Standalone
      // (outside both ShellRoute and any auth gate) since a logged-out
      // visitor has no role/nav-shell to render yet.
      GoRoute(
        path: '/jobs',
        builder: (context, state) => const PublicJobBoardScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/verification-status',
        builder: (context, state) => const VerificationStatusScreen(),
      ),
      // SEEK-01: shown once, right after a seeker signs up (see
      // register_screen.dart's post-registration navigation). Standalone
      // (outside the ShellRoute below) — no sidebar/bottom-nav chrome
      // while the seeker hasn't picked a category yet. Starts with
      // '/seeker' so the redirect guard above always lets an
      // authenticated seeker reach it.
      GoRoute(
        path: '/seeker/onboarding/preferences',
        builder: (context, state) => const CategoryPreferencesScreen(),
      ),
      // SEEK-01b: shown right after the category/preferences step above
      // (see category_preferences_screen.dart's "Save & Continue"), before
      // the seeker ever reaches their dashboard. Same standalone-route
      // reasoning as '/seeker/onboarding/preferences'.
      GoRoute(
        path: '/seeker/onboarding/cv-choice',
        builder: (context, state) => const CvChoiceScreen(),
      ),
      GoRoute(
        path: '/seeker/onboarding/cv-builder',
        builder: (context, state) => const CvBuilderScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          final role = ref.read(authProvider).user?.role ?? UserRole.seeker;
          final (navItems, brandLabel) = switch (role) {
            UserRole.seeker => (seekerNavItems, seekerBrandLabel),
            UserRole.employer => (employerNavItems, employerBrandLabel),
            UserRole.agency => (agencyNavItems, agencyBrandLabel),
            UserRole.admin => (adminNavItems, adminBrandLabel),
          };

          return ResponsiveShell(
            brandLabel: brandLabel,
            navItems: navItems,
            currentPath: state.matchedLocation,
            onNavigate: (path) => context.go(path),
            // Admin has 7 nav destinations — too many to squeeze into a
            // bottom nav bar on phones, so it keeps the sidebar (as a
            // slide-out drawer) at every screen width instead of falling
            // back to bottom nav like the other roles.
            forceSidebar: role == UserRole.admin,
            // Seekers and agencies now have a dedicated "Account" tab
            // (with sign out on it) instead of the top app bar's logout
            // icon — see `seekerNavItems`/`SeekerAccountScreen` and
            // `agencyNavItems`/`AgencyAccountScreen`.
            hideLogout: role == UserRole.seeker || role == UserRole.agency,
            headerActions: role == UserRole.seeker ? seekerHeaderActions : const [],
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/seeker/dashboard',
            builder: (context, state) => const SeekerDashboardScreen(),
          ),
          GoRoute(
            path: '/seeker/jobs',
            builder: (context, state) => const JobBoardScreen(),
          ),
          GoRoute(
            path: '/seeker/applications',
            builder: (context, state) => const MyApplicationsScreen(),
          ),
          GoRoute(
            path: '/seeker/messages',
            builder: (context, state) => const SeekerMessagesScreen(),
          ),
          GoRoute(
            path: '/seeker/account',
            builder: (context, state) => const SeekerAccountScreen(),
          ),
          GoRoute(
            path: '/employer/dashboard',
            builder: (context, state) => const EmployerDashboardScreen(),
          ),
          GoRoute(
            path: '/employer/jobs/new',
            builder: (context, state) => const PostJobScreen(),
          ),
          GoRoute(
            path: '/employer/candidates',
            builder: (context, state) => const CandidatesScreen(),
          ),
          GoRoute(
            path: '/employer/messages',
            builder: (context, state) => const EmployerMessagesScreen(),
          ),
          GoRoute(
            path: '/agency/dashboard',
            builder: (context, state) => const AgencyDashboardScreen(),
          ),
          GoRoute(
            path: '/agency/walk-in',
            builder: (context, state) => const WalkInRegistrationScreen(),
          ),
          GoRoute(
            path: '/agency/placements',
            builder: (context, state) => const PlacementsScreen(),
          ),
          GoRoute(
            path: '/agency/account',
            builder: (context, state) => const AgencyAccountScreen(),
          ),
          GoRoute(
            path: '/admin/dashboard',
            builder: (context, state) => const AdminDashboardScreen(),
          ),
          GoRoute(
            path: '/admin/verifications',
            builder: (context, state) => const AdminVerificationsScreen(),
          ),
          GoRoute(
            path: '/admin/users',
            builder: (context, state) => const AdminPlaceholderScreen(
              title: 'Users',
              icon: Icons.people_alt_outlined,
              description: 'Search, view, and suspend seeker, employer, '
                  'agency, and admin accounts.',
            ),
          ),
          GoRoute(
            path: '/admin/jobs',
            builder: (context, state) => const AdminPlaceholderScreen(
              title: 'Job Listings',
              icon: Icons.work_outline,
              description: 'Review and moderate job postings across the '
                  'platform.',
            ),
          ),
          GoRoute(
            path: '/admin/placements',
            builder: (context, state) => const AdminPlaceholderScreen(
              title: 'Placements',
              icon: Icons.assignment_turned_in_outlined,
              description: 'Platform-wide oversight of agency-brokered '
                  'placements and financials.',
            ),
          ),
          GoRoute(
            path: '/admin/sms-logs',
            builder: (context, state) => const AdminPlaceholderScreen(
              title: 'SMS Logs',
              icon: Icons.sms_outlined,
              description: 'Inbound/outbound SMS activity for debugging '
                  'the SMS-based flows.',
            ),
          ),
          GoRoute(
            path: '/admin/reports',
            builder: (context, state) => const AdminPlaceholderScreen(
              title: 'Reports',
              icon: Icons.insights_outlined,
              description: 'Growth, conversion, and payment analytics.',
            ),
          ),
        ],
      ),
    ],
  );
});

