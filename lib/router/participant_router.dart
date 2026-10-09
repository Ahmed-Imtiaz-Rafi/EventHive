import 'package:event_hive/screens/participant/event_details_screen.dart';
import 'package:event_hive/screens/participant/my_events_screen.dart';
import 'package:event_hive/screens/participant/participant_home_screen.dart';
import 'package:go_router/go_router.dart';

// Owned entirely by the teammate building Participant.
final List<RouteBase> participantRoutes = [
  GoRoute(
    path: '/participant/home',
    builder: (context, state) => const ParticipantHomeScreen(),
  ),
  GoRoute(
    // :eventId is the event's UUID, kept as a String.
    path: '/participant/event/:eventId',
    builder: (context, state) {
      final eventId = state.pathParameters['eventId']!;
      return EventDetailsScreen(eventId: eventId);
    },
  ),
  GoRoute(
    path: '/participant/my-events',
    builder: (context, state) => const MyEventsScreen(),
  ),
];