import 'package:go_router/go_router.dart';
import '../../screens/admin/admin_home_screen.dart';
import '../../screens/admin/event_oversight_screen.dart';
import '../../screens/admin/event_detail_screen.dart';
import '../../screens/admin/organizer_requests_screen.dart';
import '../../screens/admin/user_management_screen.dart';
import '../../screens/admin/analytics_screen.dart';
import '../../screens/admin/admin_profile_screen.dart';

// Owned entirely by admin. Matches the screen list already locked in.
final List<RouteBase> adminRoutes = [
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
      final eventId = int.parse(
        state.pathParameters['eventId']!,
      ); // this line was changed. int.parse was added. Any confusion in the future, this line must be consolidated
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
];
