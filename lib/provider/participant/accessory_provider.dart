import 'package:event_hive/model/common/event_accessory.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The add-ons one event offers, read from `event_accessories` and
/// grouped so each add-on appears once with its sizes.
///
/// A `.family` provider takes the event's id, so each event has its own
/// cached result. Rows are sorted by name, then by size; sorting an enum
/// column follows the order the labels were declared (xs, s, m, l...),
/// so sizes come out in a natural order.
final eventAccessoriesProvider =
    FutureProvider.family<List<EventAccessory>, String>((ref, eventId) async {
      final rows = await Supabase.instance.client
          .from('event_accessories')
          .select()
          .eq('event_id', eventId)
          .order('accessory_name', ascending: true)
          .order('size', ascending: true);

      return EventAccessory.fromRows(
        (rows as List).cast<Map<String, dynamic>>(),
      );
    });