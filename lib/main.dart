import 'package:event_hive/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://glvfjurpyrcdvwsyndmc.supabase.co',
    publishableKey: 'sb_publishable_lLTDrErew2jMWKsjLsLJXA_f9rhCguL',
  );
  runApp(ProviderScope(child: const EventHiveApp()));
}

class EventHiveApp extends StatelessWidget {
  const EventHiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MaterialApp.router takes exactly ONE routerConfig.
    // This is the single GoRouter built by merging all three
    // role-specific route files inside app_router.dart.
    return MaterialApp.router(
      title: 'EventHive',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: appRouter,
    );
  }
}
