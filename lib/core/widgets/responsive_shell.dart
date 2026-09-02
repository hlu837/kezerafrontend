import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_provider.dart';

/// One nav destination. [path] is the go_router location it navigates to;
/// [isActiveWhen] lets a destination stay highlighted for sub-routes
/// (e.g. "Candidates" active on both /employer/candidates and any detail
/// route nested under it) without every screen needing exact-path matches.
class ShellNavItem {
  const ShellNavItem({
    required this.label,
    required this.path,
    required this.icon,
  });

  final String label;
  final String path;
  final IconData icon;
}

/// Adaptive app shell shared by every authenticated role.
///
/// - Wide screens (web desktop, tablets ≥ 900px): fixed left sidebar with
///   labels, matching the Next.js `BackofficeShell` sidebar 1:1.
/// - Narrow screens (phones): a Material bottom nav bar instead, since a
///   permanent sidebar doesn't fit — same nav items, same destinations.
///   Set [forceSidebar] to true to keep the sidebar experience on narrow
///   screens too (as a slide-out [Drawer] opened from a hamburger icon)
///   instead of falling back to the bottom nav bar. This suits roles with
///   long nav lists (e.g. admin's 7 destinations) that would feel cramped
///   as bottom-nav icons.
///
/// This is the one shell every role dashboard should wrap itself in, so
/// adding a new role or a new nav item never means writing new layout
/// code — just a new [ShellNavItem] list.
class ResponsiveShell extends ConsumerWidget {
  const ResponsiveShell({
    super.key,
    required this.brandLabel,
    required this.navItems,
    required this.currentPath,
    required this.onNavigate,
    required this.child,
    this.forceSidebar = false,
    this.hideLogout = false,
    this.headerActions = const [],
  });

  /// Shown under the "KezearaJobs" wordmark, e.g. "Employer Backoffice".
  final String brandLabel;
  final List<ShellNavItem> navItems;
  final String currentPath;
  final void Function(String path) onNavigate;
  final Widget child;

  /// When true, narrow screens get the sidebar in a [Drawer] (opened via a
  /// hamburger icon) instead of a bottom nav bar. Wide screens are
  /// unaffected — they always get the fixed sidebar.
  final bool forceSidebar;

  /// When true, hides the sign-out affordance this shell would otherwise
  /// render itself (the wide-screen sidebar's "Sign out" button, and the
  /// narrow-screen app bar's logout icon) — for roles that instead surface
  /// sign out from one of their own nav destinations, e.g. the seeker
  /// role's "Account" tab.
  final bool hideLogout;

  /// Extra icon buttons shown in the narrow-screen app bar, before the
  /// logout icon (or in the space it leaves behind when [hideLogout] is
  /// true) — e.g. the seeker role's notification bell and language
  /// picker. Wide screens have no app bar, so these only render there.
  final List<Widget> headerActions;

  static const double _wideBreakpoint = 900;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    final userLabel = user?.email ?? user?.phone ?? '';
    void logout() => ref.read(authProvider.notifier).logout();

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(
              brandLabel: brandLabel,
              navItems: navItems,
              currentPath: currentPath,
              onNavigate: onNavigate,
              userLabel: userLabel,
              onLogout: hideLogout ? null : logout,
            ),
            Expanded(child: child),
          ],
        ),
      );
    }

    if (forceSidebar) {
      return Scaffold(
        appBar: AppBar(title: Text(brandLabel)),
        drawer: Drawer(
          child: SafeArea(
            child: _Sidebar(
              brandLabel: brandLabel,
              navItems: navItems,
              currentPath: currentPath,
              // Close the drawer, then navigate, so the drawer doesn't
              // stay open over the newly-pushed page.
              onNavigate: (path) {
                Navigator.of(context).pop();
                onNavigate(path);
              },
              userLabel: userLabel,
              onLogout: () {
                Navigator.of(context).pop();
                logout();
              },
            ),
          ),
        ),
        body: child,
      );
    }

    final activeIndex = navItems.indexWhere((i) => i.path == currentPath);

    return Scaffold(
      appBar: AppBar(
        title: Text(brandLabel),
        actions: [
          ...headerActions,
          if (!hideLogout)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sign out',
              onPressed: logout,
            ),
        ],
      ),
      body: child,
      bottomNavigationBar: navItems.length < 2
          ? null
          : NavigationBar(
              selectedIndex: activeIndex < 0 ? 0 : activeIndex,
              onDestinationSelected: (index) =>
                  onNavigate(navItems[index].path),
              destinations: [
                for (final item in navItems)
                  NavigationDestination(
                    icon: Icon(item.icon),
                    label: item.label,
                  ),
              ],
            ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.brandLabel,
    required this.navItems,
    required this.currentPath,
    required this.onNavigate,
    required this.userLabel,
    this.onLogout,
  });

  final String brandLabel;
  final List<ShellNavItem> navItems;
  final String currentPath;
  final void Function(String path) onNavigate;
  final String userLabel;

  /// Null hides the "Sign out" button entirely — see
  /// `ResponsiveShell.hideLogout`.
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(right: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KezearaJobs',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  brandLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final item in navItems)
                  _SidebarLink(
                    item: item,
                    isActive: item.path == currentPath,
                    onTap: () => onNavigate(item.path),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (onLogout != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: onLogout,
                    child: const Text('Sign out'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarLink extends StatelessWidget {
  const _SidebarLink({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final ShellNavItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isActive ? colorScheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: isActive
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: TextStyle(
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    color: isActive
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
