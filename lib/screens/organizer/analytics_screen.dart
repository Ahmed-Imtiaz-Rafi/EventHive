import 'package:event_hive/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Placeholder screen for Analytics — full design will be added later
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kNavy,
        title: const Text('Analytics', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/organizer/home'),
        ),
      ),
      body: const Center(
        child: Text(
          'Analytics — coming soon',
          style: TextStyle(color: kTextSub),
        ),
      ),
    );
  }
}
