import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/agency/presentation/agency_account_screen.dart';
import '../../features/agency/presentation/agency_commission_screen.dart';
import '../../features/agency/presentation/agency_dashboard_screen.dart';
import '../../features/agency/presentation/agency_registration_screen.dart';
import '../../features/agency/presentation/agency_shell.dart';
import '../../features/agency/presentation/placements_screen.dart';
import '../../features/admin/presentation/admin_conversations_screen.dart';
import '../../features/admin/presentation/admin_jobs_screen.dart';
import '../../features/admin/presentation/admin_placements_screen.dart';
import '../../features/admin/presentation/admin_reports_screen.dart';
import '../../features/admin/presentation/admin_sms_logs_screen.dart';
import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../features/admin/presentation/admin_shell.dart';
import '../../features/admin/presentation/admin_subscriptions_screen.dart';
import '../../features/admin/presentation/admin_users_screen.dart';
import '../../features/admin/presentation/admin_verifications_screen.dart';
import '../../features/auth/domain/auth_payloads.dart';
import '../../features/auth/domain/user_model.dart';
import '../../features/auth/presentation/auth_provider.dart';
import '../../features/auth/presentation/auth_state.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/verification_resubmit_screen.dart';
import '../../features/auth/presentation/verification_status_screen.dart';
import '../../features/employer/presentation/employer_account_screen.dart';
import '../../features/employer/presentation/employer_dashboard_screen.dart';
import '../../features/employer/presentation/employer_jobs_screen.dart';
import '../../features/employer/presentation/employer_messages_screen.dart';
import '../../features/employer/presentation/employer_shell.dart';
import '../../features/jobs/domain/job.dart';
import '../../features/jobs/presentation/job_board_screen.dart';
import '../../features/jobs/presentation/nearby_map_screen.dart';
import '../../features/jobs/presentation/post_job_screen.dart';
import '../../features/jobs/presentation/public_job_board_screen.dart';
import '../../features/seeker/presentation/candidates_screen.dart';
import '../../features/seeker/presentation/category_preferences_screen.dart';
import '../../features/seeker/presentation/cv_builder_screen.dart';
import '../../features/seeker/presentation/cv_choice_screen.dart';
import '../../features/seeker/presentation/expert_type_choice_screen.dart';
import '../../features/seeker/presentation/technician_registration_screen.dart';
import '../../features/seeker/presentation/expert_categories_screen.dart';
import '../../features/seeker/presentation/my_applications_screen.dart';
import '../../features/seeker/presentation/seeker_account_screen.dart';
import '../../features/seeker/presentation/seeker_dashboard_screen.dart';
import '../../features/seeker/presentation/seeker_messages_screen.dart';
import '../../features/seeker/presentation/seeker_shell.dart';
import '../../features/service_requests/presentation/service_requests_screen.dart';
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
      // Login/register only make sense logged out — an already-
      // authenticated user hitting either gets bounced to their own
      // dashboard instead.
      const guestOnlyRoutes = {'/login', '/register'};
      // Guest-facing browse content (job board, Experts/Agencies
      // directories+maps): reachable by a logged-out visitor AND left
      // alone for an authenticated user too, since an employer/agency
      // needs to actually land on these to use their own Chat/Call/Send
      // Job Request actions (see nearby_experts_map_screen.dart /
      // nearby_agencies_map_screen.dart) — unlike guestOnlyRoutes above,
      // these are not exclusively for logged-out visitors.
      const guestAccessibleRoutes = {
        '/jobs',
        '/experts/nearby',
        '/experts/categories',
        '/agencies/nearby',
      };
      const verificationRoutes = {'/verification-status', '/verification/resubmit'};
      final isGoingToGuestOnlyRoute = guestOnlyRoutes.contains(location);
      final isGoingToGuestAccessibleRoute = guestAccessibleRoutes.contains(location);
      final isGoingToVerificationRoute = verificationRoutes.contains(location);

      switch (authState.status) {
        case AuthStatus.unknown:
          // Startup hydration in flight — root builder shows a splash, and
          // there's nothing safe to redirect to yet.
          return null;

        case AuthStatus.authenticating:
        case AuthStatus.unauthenticated:
          return (isGoingToGuestOnlyRoute || isGoingToGuestAccessibleRoute)
              ? null
              : '/login';

        case AuthStatus.authenticated:
          final user = authState.user!;
          final role = user.role;
          final dashboardPath = role.dashboardPath;
          final allowedPrefix = _roleRoutePrefix[role]!;

          if (isGoingToGuestOnlyRoute) return dashboardPath;

          // Browse content stays reachable once logged in — skips both
          // the role-prefix guard below and (deliberately) the
          // verification guard beneath it too: browsing a map doesn't
          // require an approved profile, only *acting* from it does
          // (POST /placements/invite already enforces `requireApproved`
          // server-side regardless of what the client lets you tap).
          if (isGoingToGuestAccessibleRoute) return null;

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
      // "Experts" directory — trade categories with counts (see
      // public_candidates_board_screen.dart's "Browse experts by
      // category" button). Standalone/no-auth, same reasoning as
      // `/jobs` below.
      GoRoute(
        path: '/experts/categories',
        builder: (context, state) => const ExpertCategoriesScreen(),
      ),
      // "Find an expert near you" — reachable from the public landing
      // page's "Experts" tab (see public_candidates_board_screen.dart's
      // "View on map" button) and from tapping a category card on
      // `/experts/categories` above, which passes `?trade=<key>` to
      // preset the trade filter. Standalone/no-auth for the same reason
      // as `/jobs` above: a guest client looking for a tradesperson has
      // no role/nav-shell yet either.
      //
      // Both this route and `/agencies/nearby` below now build the same
      // merged `NearbyMapScreen` (Experts/Agencies toggle) — see that
      // file's doc comment — just with a different starting mode, so
      // whichever tab someone entered from, they can flip to the other
      // without leaving the screen.
      GoRoute(
        path: '/experts/nearby',
        builder: (context, state) {
          final trade = state.uri.queryParameters['trade'];
          return NearbyMapScreen(
            initialMode: NearbyMapMode.experts,
            initialTrade: trade,
          );
        },
      ),
      // "Find agencies near you" — reachable from the public landing
      // page's "Agencies" tab (see public_agency_screen.dart's "View on
      // map" button). Standalone/no-auth for the same reason as
      // `/experts/nearby` above.
      GoRoute(
        path: '/agencies/nearby',
        builder: (context, state) =>
            const NearbyMapScreen(initialMode: NearbyMapMode.agencies),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) {
          // ?role=agency|employer|seeker preselects the role tile — used
          // by the public "Agency" landing tab's CTA (see
          // public_agency_screen.dart) to skip straight to that form.
          // Unrecognized/missing values fall back to the seeker default,
          // same as before this param existed.
          final roleParam = state.uri.queryParameters['role'];
          RegisterableRole? initialRole;
          for (final r in RegisterableRole.values) {
            if (r.name == roleParam) {
              initialRole = r;
              break;
            }
          }
          return RegisterScreen(initialRole: initialRole);
        },
      ),
      GoRoute(
        path: '/verification-status',
        builder: (context, state) => const VerificationStatusScreen(),
      ),
      GoRoute(
        path: '/verification/resubmit',
        builder: (context, state) => const VerificationResubmitScreen(),
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
      // SEEK-01c: shown right after the category/preferences step above
      // (see category_preferences_screen.dart's "Save & Continue"),
      // one step ahead of the CV choice screen — lets a brand-new
      // seeker pick whether they're a formal (CV) job seeker, a Trade
      // Technician, or (via "Skip for now") neither yet. Same
      // standalone-route reasoning as the routes above.
      GoRoute(
        path: '/seeker/onboarding/expert-choice',
        builder: (context, state) => const ExpertTypeChoiceScreen(),
      ),
      // The lightweight Trade Technician registration form — reached
      // either from the choice screen above (`context.go`, onboarding)
      // or pushed from the account screen's "Job seeking" section
      // (`context.push`, editing an existing profile). Same standalone
      // reasoning; also fine to reach post-onboarding since it starts
      // with '/seeker'.
      GoRoute(
        path: '/seeker/onboarding/technician-registration',
        builder: (context, state) => const TechnicianRegistrationScreen(),
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
            // Admin has 7 nav destinations, and agency now has 6 (with
            // the addition of the "Candidates" tab) — both too many to
            // squeeze into a bottom nav bar on phones, so they keep the
            // sidebar (as a slide-out drawer) at every screen width
            // instead of falling back to bottom nav like seeker/employer.
            forceSidebar: role == UserRole.admin || role == UserRole.agency,
            // Seekers, agencies, and employers now have a dedicated
            // "Account" tab (with sign out on it) instead of the top app
            // bar's logout icon — see `seekerNavItems`/`SeekerAccountScreen`,
            // `agencyNavItems`/`AgencyAccountScreen`, and
            // `employerNavItems`/`EmployerAccountScreen`.
            hideLogout: role == UserRole.seeker ||
                role == UserRole.agency ||
                role == UserRole.employer,
            headerActions: switch (role) {
              UserRole.seeker => seekerHeaderActions,
              UserRole.employer => employerHeaderActions,
              UserRole.agency => agencyHeaderActions,
              _ => const [],
            },
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
          // "My Requests" (bookings this seeker has made, e.g. hiring a
          // fellow Expert) plus "Incoming" (requests routed to them as
          // an Expert, when `tradeCategory` is set) — reachable from
          // SeekerAccountScreen's "Service requests" row.
          GoRoute(
            path: '/seeker/service-requests',
            builder: (context, state) => const ServiceRequestsScreen(),
          ),
          GoRoute(
            path: '/employer/dashboard',
            builder: (context, state) => const EmployerDashboardScreen(),
          ),
          GoRoute(
            path: '/employer/jobs',
            // The full "my job postings" list — see
            // `EmployerDashboardScreen`'s doc comment for why this is
            // split out from the dashboard itself.
            builder: (context, state) => const EmployerJobsScreen(),
          ),
          GoRoute(
            path: '/employer/jobs/new',
            builder: (context, state) => const PostJobScreen(),
          ),
          GoRoute(
            path: '/employer/jobs/edit',
            // The job to edit is passed via `extra` (from
            // `EmployerJobsScreen`'s "Edit" button) rather than
            // re-fetched by id, since that screen already has the
            // full, current `Job` in memory.
            builder: (context, state) =>
                PostJobScreen(job: state.extra as Job),
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
            path: '/employer/account',
            builder: (context, state) => const EmployerAccountScreen(),
          ),
          // "My Requests" only — an employer never receives incoming
          // service requests (see `serviceRequests.service.js
          // #listIncomingRequests`'s 403 for any role but seeker/agency),
          // so `ServiceRequestsScreen` hides that tab for this role.
          GoRoute(
            path: '/employer/service-requests',
            builder: (context, state) => const ServiceRequestsScreen(),
          ),
          GoRoute(
            path: '/agency/dashboard',
            builder: (context, state) => const AgencyDashboardScreen(),
          ),
          GoRoute(
            path: '/agency/jobs/new',
            builder: (context, state) => const PostJobScreen(),
          ),
          GoRoute(
            path: '/agency/jobs/edit',
            // Same pass-by-`extra` pattern as '/employer/jobs/edit' —
            // the dashboard already has the full, current `Job` in
            // memory, so there's no need to re-fetch it by id.
            builder: (context, state) =>
                PostJobScreen(job: state.extra as Job),
          ),
          GoRoute(
            path: '/agency/walk-in',
            builder: (context, state) => const AgencyRegistrationScreen(),
          ),
          GoRoute(
            path: '/agency/candidates',
            builder: (context, state) => const CandidatesScreen(),
          ),
          GoRoute(
            path: '/agency/placements',
            builder: (context, state) => const PlacementsScreen(),
          ),
          GoRoute(
            path: '/agency/commission',
            builder: (context, state) => const AgencyCommissionScreen(),
          ),
          GoRoute(
            path: '/agency/account',
            builder: (context, state) => const AgencyAccountScreen(),
          ),
          // "My Requests" (this agency booking another Expert/agency)
          // plus "Incoming" (requests routed to this agency, including
          // ones still awaiting assignment to a roster member).
          GoRoute(
            path: '/agency/service-requests',
            builder: (context, state) => const ServiceRequestsScreen(),
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
            path: '/admin/conversations',
            builder: (context, state) => const AdminConversationsScreen(),
          ),
          GoRoute(
            path: '/admin/subscriptions',
            builder: (context, state) => const AdminSubscriptionsScreen(),
          ),
          GoRoute(
            path: '/admin/users',
            builder: (context, state) => const AdminUsersScreen(),
          ),
          GoRoute(
            path: '/admin/jobs',
            builder: (context, state) => const AdminJobsScreen(),
          ),
          GoRoute(
            path: '/admin/placements',
            builder: (context, state) => const AdminPlacementsScreen(),
          ),
          GoRoute(
            path: '/admin/sms-logs',
            builder: (context, state) => const AdminSmsLogsScreen(),
          ),
          GoRoute(
            path: '/admin/reports',
            builder: (context, state) => const AdminReportsScreen(),
          ),
        ],
      ),
    ],
  );
});

