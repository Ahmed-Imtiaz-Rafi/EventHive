import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Names of all event categories, read from the `event_categories` table.
///
/// Lives in `common` because both roles need it: participants filter
/// events by it, and organizers pick from it when creating an event.
/// Reading the table (not the events) means a category appears as soon
/// as it is inserted, even before any event uses it.
///
/// Contains real categories only. The participant filter's extra "All"
/// option is added by the UI, see `kAllCategory` in `event_provider.dart`.
final categoriesProvider = FutureProvider<List<String>>((ref) async {
  final rows = await Supabase.instance.client
      .from('event_categories')
      .select('category_name')
      .order('category_name');

  return (rows as List).map((row) => row['category_name'] as String).toList();
});