import 'package:event_hive/model/common/event_role.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The roles one event offers, with fees and tracks.
///
/// Reads `event_role_price` (only the roles listed there can be taken;
/// price 0 means free) and `event_role_track`. A `.family` provider takes
/// the event's id, so each event has its own cached result. Sorted by
/// name because the tables have no order column.
final eventRolesProvider = FutureProvider.family<List<EventRole>, String>((
  ref,
  eventId,
) async {
  final client = Supabase.instance.client;

  final roleRows = await client
      .from('event_role_price')
      .select()
      .eq('event_id', eventId)
      .order('role_name', ascending: true);

  final trackRows = await client
      .from('event_role_track')
      .select('role_name, track_name')
      .eq('event_id', eventId)
      .order('track_name', ascending: true);

  // Group the tracks by role name.
  final tracksByRole = <String, List<String>>{};
  for (final row in (trackRows as List)) {
    tracksByRole
        .putIfAbsent(row['role_name'] as String, () => [])
        .add(row['track_name'] as String);
  }

  return (roleRows as List).map((row) {
    final map = row as Map<String, dynamic>;
    return EventRole.fromMap(
      map,
      tracks: tracksByRole[map['role_name']] ?? const [],
    );
  }).toList();
});