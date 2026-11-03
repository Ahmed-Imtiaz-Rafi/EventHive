import 'package:event_hive/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Navy bar at the top of a screen: a back arrow and a title.
///
/// Shared by every screen that has a back button. [fallbackRoute] is
/// where Back goes when there is no previous screen (for example after
/// a browser refresh, when the navigation stack is empty).
class AppHeaderBar extends StatelessWidget {
  final String title;
  final String fallbackRoute;

  const AppHeaderBar({
    super.key,
    required this.title,
    required this.fallbackRoute,
  });

  /// Goes back to the previous screen, or to [fallbackRoute] if there
  /// is none, instead of doing nothing.
  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(fallbackRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: kNavy,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _goBack(context),
            icon: const Icon(Icons.chevron_left, color: Colors.white),
          ),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'serif',
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}