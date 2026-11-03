import 'package:event_hive/model/common/announcement.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The announcements the logged-in user may see, newest first, read from
/// the `my_announcements` view (which already filters to the user's own
/// events and clubs). `autoDispose` so it never shows another user's
/// messages after a logout.
final myAnnouncementsProvider = FutureProvider.autoDispose<
  List<Announcement>
>((ref) async {
  final rows = await Supabase.instance.client
      .from('my_announcements')
      .select()
      .order('created_at', ascending: false);

  return (rows as List)
      .map((row) => Announcement.fromMap(row as Map<String, dynamic>))
      .toList();
});

/// How many announcements the logged-in user has not read yet. Used by
/// the badges on Home and Profile.
final unreadNotificationsProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  final rows = await Supabase.instance.client
      .from('my_announcements')
      .select('announcement_id')
      .eq('is_read', false);

  return (rows as List).length;
});

/// Things the user can do to an announcement.
class AnnouncementActions {
  /// Records that the user has read it. Not important enough to bother
  /// the user if it fails, so errors only go to the console.
  Future<void> markRead(String announcementId) async {
    try {
      await Supabase.instance.client.rpc(
        'mark_announcement_read',
        params: {'p_announcement_id': announcementId},
      );
    } catch (e) {
      debugPrint('Could not mark the announcement as read: $e');
    }
  }
}

final announcementActionsProvider = Provider<AnnouncementActions>(
  (ref) => AnnouncementActions(),
);