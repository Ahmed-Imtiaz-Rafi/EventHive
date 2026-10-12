import 'package:event_hive/model/common/event.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ------------------------------------------------------------------
// Home screen input state
// ------------------------------------------------------------------

/// Value of the category chip that means "no category filter".
/// It is not a row in `event_categories`; it exists only in the
/// participant filter.
const kAllCategory = 'All';

/// Text currently typed in the search bar.
/// Written by the search bar, read by [filteredEventsProvider].
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(
  SearchQueryNotifier.new,
);

/// Category chip currently selected; [kAllCategory] means no filtering.
/// Written by the chips, read by [filteredEventsProvider].
class SelectedCategoryNotifier extends Notifier<String> {
  @override
  String build() => kAllCategory;

  void select(String value) => state = value;
}

final selectedCategoryProvider =
    NotifierProvider<SelectedCategoryNotifier, String>(
      SelectedCategoryNotifier.new,
    );

// ------------------------------------------------------------------
// Event data (from Supabase)
// ------------------------------------------------------------------

/// All upcoming, active events, soonest first.
///
/// Reads the `event_overview` view (events + category name +
/// registered_count). "Upcoming" is not stored in the database; it is
/// derived by comparing `event_date` with today, so an event stays
/// upcoming for its whole date, even after its start time has passed.
/// Cancelled events are excluded through the `status` column.
///
/// The result is cached for the session. Call
/// `ref.refresh(upcomingEventsProvider.future)` to fetch fresh data
/// (the home list does this on pull-to-refresh).
final upcomingEventsProvider = FutureProvider<List<Event>>((ref) async {
  // 'YYYY-MM-DD' matches the format of the DATE column.
  final today = DateTime.now().toIso8601String().split('T').first;

  final rows = await Supabase.instance.client
      .from('event_overview')
      .select()
      .eq('status', 'active')
      .gte('event_date', today)
      .order('event_date', ascending: true);

  return (rows as List)
      .map((row) => Event.fromMap(row as Map<String, dynamic>))
      .toList();
});

// ------------------------------------------------------------------
// Derived state
// ------------------------------------------------------------------

/// The events the list actually shows: [upcomingEventsProvider] narrowed
/// by the selected chip and the search text.
///
/// It re-runs automatically whenever any of its three inputs change, so
/// no widget ever filters by hand. Filtering happens in Dart (not in the
/// query) because the list is small and results then update instantly
/// with every keystroke.
///
/// While the events are loading, or if loading failed, this is an empty
/// list. Widgets that must tell those cases apart watch
/// [upcomingEventsProvider] directly.
final filteredEventsProvider = Provider<List<Event>>((ref) {
  // maybeWhen is safe in every state; it never throws on errors.
  final events = ref
      .watch(upcomingEventsProvider)
      .maybeWhen(data: (list) => list, orElse: () => <Event>[]);
  final category = ref.watch(selectedCategoryProvider);
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();

  return events.where((e) {
    final matchesCategory =
    category == kAllCategory || e.categories.contains(category);
    final matchesSearch =
        query.isEmpty || e.title.toLowerCase().contains(query);
    return matchesCategory && matchesSearch;
  }).toList();
});

// ------------------------------------------------------------------
// Single event (details screen)
// ------------------------------------------------------------------

/// One event by id, for the details screen.
///
/// A `.family` provider is a provider that takes an argument: each
/// event id gets its own cached result, so opening the same event twice
/// does not fetch twice. Unlike [upcomingEventsProvider] there is no
/// date or status filter, because a participant can also open an event
/// that is cancelled or already past (for example from My events).
/// `.single()` throws when no row matches, which shows as the error
/// state on the screen.
final eventDetailsProvider = FutureProvider.family<Event, String>((
  ref,
  eventId,
) async {
  final row = await Supabase.instance.client
      .from('event_overview')
      .select()
      .eq('event_id', eventId)
      .single();

  return Event.fromMap(row);
});