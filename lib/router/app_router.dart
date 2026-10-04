import 'package:event_hive/router/admin_router.dart';
import 'package:event_hive/router/organizer_router.dart';
import 'package:event_hive/router/participant_router.dart';
import 'package:event_hive/screens/common/login_screen.dart';
import 'package:event_hive/screens/common/pending_organizer_screen.dart';
import 'package:event_hive/screens/common/register_screen.dart';
import 'package:event_hive/screens/common/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// This is the ONLY GoRouter instance in the whole app.
// Each role's routes are written and owned separately (see the three
// files above), but they all get merged into this one route list.
final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/pending-organizer',
      builder: (context, state) => const PendingOrganizerScreen(),
    ),

    // Each role contributes its own branch — no file above needs to
    // know the other two branches exist.
    ...organizerRoutes,
    ...adminRoutes,
    ...participantRoutes,
  ],
);

// --------------------------------------------------------------------
// The one piece of shared LOGIC (not UI) that decides which branch a
// user lands in right after login. This is the dispatch point we
// talked about — the only place that needs to know about all three
// roles at once.
// --------------------------------------------------------------------
void goToRoleHome(BuildContext context, String currentUserRole) {
  switch (currentUserRole) {
    case 'organizer':
      context.go('/organizer/home');
      break;
    case 'admin':
      context.go('/admin/home');
      break;
    case 'participant':
      context.go('/participant/home');
      break;
    default:
      // e.g. applied for organizer, still awaiting approval
      context.go('/pending-organizer');
  }
}
