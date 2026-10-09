import 'package:event_hive/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Frame around the three participant tabs: Home, My events, Profile.
///
/// The router (see `participant_router.dart`) builds this once and puts
/// the active tab's screen in [navigationShell]. The bottom bar lives
/// here, so no tab screen builds its own and any new tab only needs a
/// route and a bar item.
class ParticipantShell extends StatelessWidget {
  /// Holds the tabs and knows which one is selected.
  final StatefulNavigationShell navigationShell;

  const ParticipantShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(child: navigationShell),

      // ---- Bottom navigation bar ----
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        // goBranch switches tab. Tapping the tab that is already open
        // (initialLocation: true) returns it to its first screen.
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        // "fixed" keeps labels visible on all tabs, as in the design.
        type: BottomNavigationBarType.fixed,
        backgroundColor: kSurface,
        selectedItemColor: kNavy,
        unselectedItemColor: kTextSub,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            label: 'My events',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}