/// One message an organizer or admin sent, as the logged-in user sees it:
/// a row of the `my_announcements` view.
class Announcement {
  final String id;

  /// 'event' (sent to one event's people) or 'club'.
  final String scope;

  /// The event it is about; null for club messages.
  final String? eventId;
  final String title;
  final String body;
  final DateTime createdAt;

  /// True once the user has opened it.
  final bool isRead;

  const Announcement({
    required this.id,
    required this.scope,
    required this.eventId,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
  });

  factory Announcement.fromMap(Map<String, dynamic> map) {
    return Announcement(
      id: map['announcement_id'] as String,
      scope: map['scope'] as String,
      eventId: map['event_id'] as String?,
      title: map['title'] as String,
      body: map['body'] as String,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      isRead: map['is_read'] as bool,
    );
  }
}