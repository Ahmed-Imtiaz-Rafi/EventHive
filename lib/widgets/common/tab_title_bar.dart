import 'package:event_hive/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Navy title bar for the bottom-bar tabs (My events, Profile). Unlike
/// `AppHeaderBar` it has no back arrow, because a tab is a top-level
/// place, not a step you can go back from.
class TabTitleBar extends StatelessWidget {
  final String title;
  const TabTitleBar({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: kNavy,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'serif',
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}