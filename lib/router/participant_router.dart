import 'package:go_router/go_router.dart';
import '../screens/participant/participant_home_screen.dart';
import '../../screens/participant/event_details_screen.dart';
import '../../screens/participant/my_events_screen.dart';

// Owned entirely by the teammate building Participant.
final List<RouteBase> participantRoutes = [
  GoRoute(
    path: '/participant/home',
    builder: (context, state) => const ParticipantHomeScreen(),
  ),
  GoRoute(
    path: '/participant/event/:eventId',
    builder: (context, state) {
      final eventId = int.parse(state.pathParameters['eventId']!);
      return EventDetailsScreen(eventId: eventId);
    },
  ),
  GoRoute(
    path: '/participant/my-events',
    builder: (context, state) => const MyEventsScreen(),
  ),
];
