import 'package:event_hive/screens/organizer/analytics_screen.dart';
import 'package:event_hive/screens/organizer/create_event_screen.dart';
import 'package:event_hive/screens/organizer/edit_event_screen.dart';
import 'package:event_hive/screens/organizer/guest_list_screen.dart';
import 'package:event_hive/screens/organizer/manage_event_screen.dart';
import 'package:event_hive/screens/organizer/my_events_screen.dart';
import 'package:event_hive/screens/organizer/organizer_home_screen.dart';
import 'package:event_hive/screens/organizer/organizer_profile_screen.dart';
import 'package:event_hive/screens/organizer/pricing_addons_screen.dart';
import 'package:go_router/go_router.dart';

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
    path: '/organizer/my-events',
    builder: (context, state) => const MyEventsScreen(),
  ),
  // Bottom nav Analytics — no specific event, shows a picker message
  GoRoute(
    path: '/organizer/analytics',
    builder: (context, state) => const AnalyticsScreen(),
  ),
  GoRoute(
    path: '/organizer/profile',
    builder: (context, state) => const OrganizerProfileScreen(),
  ),
  GoRoute(
    path: '/organizer/event/:eventId',
    builder: (context, state) {
      final eventId = state.pathParameters['eventId']!;
      return ManageEventScreen(eventId: eventId);
    },
  ),
  GoRoute(
    path: '/organizer/event/:eventId/edit',
    builder: (context, state) {
      final eventId = state.pathParameters['eventId']!;
      return EditEventScreen(eventId: eventId);
    },
  ),
  // Screen 5 — Pricing & Add-ons
  GoRoute(
    path: '/organizer/event/:eventId/pricing',
    builder: (context, state) {
      final eventId = state.pathParameters['eventId']!;
      return PricingAddonsScreen(eventId: eventId);
    },
  ),
  // Screen 6 — Guest List & Payments
  GoRoute(
    path: '/organizer/event/:eventId/guests',
    builder: (context, state) {
      final eventId = state.pathParameters['eventId']!;
      return GuestListScreen(eventId: eventId);
    },
  ),
  // Screen 7 — Analytics per event
  GoRoute(
    path: '/organizer/event/:eventId/analytics',
    builder: (context, state) {
      final eventId = state.pathParameters['eventId']!;
      return AnalyticsScreen(eventId: eventId);
    },
  ),
];
