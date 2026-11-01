import 'package:event_hive/screens/participant/cancel_registration_screen.dart';
import 'package:event_hive/screens/participant/edit_profile_screen.dart';
import 'package:event_hive/screens/participant/event_addons_preview_screen.dart';
import 'package:event_hive/screens/participant/event_addons_screen.dart';
import 'package:event_hive/screens/participant/event_details_screen.dart';
import 'package:event_hive/screens/participant/my_events_screen.dart';
import 'package:event_hive/screens/participant/my_ticket_screen.dart';
import 'package:event_hive/screens/participant/notifications_screen.dart';
import 'package:event_hive/screens/participant/participant_home_screen.dart';
import 'package:event_hive/screens/participant/participant_profile_screen.dart';
import 'package:event_hive/screens/participant/participant_shell.dart';
import 'package:event_hive/screens/participant/payment_screen.dart';
import 'package:event_hive/screens/participant/select_role_screen.dart';
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
            // The registration pages belong to this tab, so the bottom
            // bar stays visible and Back returns to the list.
            routes: [
              GoRoute(
                // Pay for a registration, or see where it stands.
                path: 'registration/:registrationId',
                builder: (context, state) => PaymentScreen(
                  registrationId: state.pathParameters['registrationId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'ticket',
                    builder: (context, state) => MyTicketScreen(
                      registrationId: state.pathParameters['registrationId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'cancel',
                    builder: (context, state) => CancelRegistrationScreen(
                      registrationId: state.pathParameters['registrationId']!,
                    ),
                  ),
                ],
              ),
            ],
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
  GoRoute(
    // Step 1 of registration for the event in the path.
    path: '/participant/event/:eventId/role',
    builder: (context, state) {
      final eventId = state.pathParameters['eventId']!;
      return SelectRoleScreen(eventId: eventId);
    },
  ),
  GoRoute(
    // Step 2 of registration: choose add-ons for the event in the path.
    path: '/participant/event/:eventId/addons',
    builder: (context, state) {
      final eventId = state.pathParameters['eventId']!;
      return EventAddonsScreen(eventId: eventId);
    },
  ),
  GoRoute(
    // Read-only list of the event's add-ons. No registration needed.
    path: '/participant/event/:eventId/addons-preview',
    builder: (context, state) {
      final eventId = state.pathParameters['eventId']!;
      return EventAddonsPreviewScreen(eventId: eventId);
    },
  ),
  GoRoute(
    // Edit phone, student ID and department.
    path: '/participant/profile/edit',
    builder: (context, state) => const EditProfileScreen(),
  ),
  GoRoute(
    // Opened from the Home bell and the Profile menu, so it belongs to
    // no single tab.
    path: '/participant/notifications',
    builder: (context, state) => const NotificationsScreen(),
  ),
];