import 'package:event_hive/screens/participant/event_details_screen.dart';
import 'package:event_hive/screens/participant/my_events_screen.dart';
import 'package:event_hive/screens/participant/participant_home_screen.dart';
import 'package:event_hive/screens/participant/participant_profile_screen.dart';
import 'package:event_hive/screens/participant/participant_shell.dart';
import 'package:go_router/go_router.dart';

// Owned entirely by the teammate building Participant.
final List<RouteBase> participantRoutes = [
  // ---- Tabs: shown inside the shell, with the bottom bar ----
  // Each branch is one tab, in the same order as the bar items.
  StatefulShellRoute.indexedStack(
    builder: (context, state, navigationShell) =>
        ParticipantShell(navigationShell: navigationShell),
    branches: [
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/participant/home',
            builder: (context, state) => const ParticipantHomeScreen(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/participant/my-events',
            builder: (context, state) => const MyEventsScreen(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/participant/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  ),

  // ---- Full screens: no bottom bar ----
  GoRoute(
    // :eventId is the event's UUID, kept as a String.
    path: '/participant/event/:eventId',
    builder: (context, state) {
      final eventId = state.pathParameters['eventId']!;
      return EventDetailsScreen(eventId: eventId);
    },
  ),
];