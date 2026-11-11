import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../screens/admin/admin_home_screen.dart';
import '../../screens/admin/event_oversight_screen.dart';
import '../../screens/admin/event_detail_screen.dart';
import '../../screens/admin/organizer_requests_screen.dart';
import '../../screens/admin/user_management_screen.dart';
import '../../screens/admin/analytics_screen.dart';
import '../../screens/admin/admin_profile_screen.dart';

// Owned entirely by admin. One ShellRoute keeps the bottom nav bar
// (Home / Analytics / Profile) alive across every admin screen.
final List<RouteBase> adminRoutes = [
  ShellRoute(
    builder: (context, state, child) =>
        _AdminShell(location: state.uri.path, child: child),
    routes: [
      GoRoute(
        path: '/admin/home',
        builder: (context, state) => const AdminHomeScreen(),
      ),
      GoRoute(
        path: '/admin/events',
        builder: (context, state) => const EventOversightScreen(),
      ),
      GoRoute(
        path: '/admin/events/:eventId',
        builder: (context, state) {
          // event_id is a UUID, so it stays a String. Never int.parse it.
          final eventId = state.pathParameters['eventId']!;
          return EventDetailScreen(eventId: eventId);
        },
      ),
      GoRoute(
        path: '/admin/organizer-requests',
        builder: (context, state) => const OrganizerRequestsScreen(),
      ),
      GoRoute(
        path: '/admin/users',
        builder: (context, state) => const UserManagementScreen(),
      ),
      GoRoute(
        path: '/admin/analytics',
        builder: (context, state) => const AnalyticsScreen(),
      ),
      GoRoute(
        path: '/admin/profile',
        builder: (context, state) => const AdminProfileScreen(),
      ),
    ],
  ),
];

/// Bottom navigation wrapper shared by every admin screen.
class _AdminShell extends StatelessWidget {
  final String location;
  final Widget child;
  const _AdminShell({required this.location, required this.child});

  static const _tabs = ['/admin/home', '/admin/analytics', '/admin/profile'];

  // Drill-down pages (events, users, requests) count as the Home tab.
  int get _index {
    if (location.startsWith('/admin/analytics')) return 1;
    if (location.startsWith('/admin/profile')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => context.go(_tabs[i]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
