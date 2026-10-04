import 'package:event_hive/screens/organizer/create_event_screen.dart';
import 'package:event_hive/screens/organizer/manage_event_screen.dart';
import 'package:event_hive/screens/organizer/organizer_home_screen.dart';
import 'package:go_router/go_router.dart';

// Owned entirely by the teammate building Organizer.
// Nobody else needs to touch this file to add/change organizer screens.
final List<RouteBase> organizerRoutes = [
  GoRoute(
    path: '/organizer/home',
    builder: (context, state) => const OrganizerHomeScreen(),
  ),
  GoRoute(
    path: '/organizer/create-event',
    builder: (context, state) => const CreateEventScreen(),
  ),
  GoRoute(
    path: '/organizer/event/:eventId',
    builder: (context, state) {
      final eventId = int.parse(
        state.pathParameters['eventId']!,
      ); // this line was modified by adding int.parse. see other similar type of files as well.
      return ManageEventScreen(eventId: eventId);
    },
  ),
];
