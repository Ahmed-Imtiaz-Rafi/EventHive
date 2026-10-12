/// One event as shown on the participant screens.
///
/// Plain data class: holds values and small derived helpers, no UI and
/// no database calls. It maps one row of the `event_overview` view
/// (the `events` table + category name + registration count).
class Event {
  // ------------------------------------------------------------------
  // Fields
  // ------------------------------------------------------------------

  /// Primary key (`events.event_id`).
  final String id;

  /// Event name (`events.name`), e.g. 'Tech Fest 2027'.
  final String title;

  /// Names of the categories this event belongs to, from
  /// `event_categories` through `event_category_map`. An event can have
  /// several (e.g. ['CSE', 'Workshop']); the list is empty if none.
  final List<String> categories;

  /// Start moment, built from `event_date` + `start_time`.
  final DateTime startsAt;

  /// Where it happens (`events.venue`).
  final String venue;

  /// Maximum participants (`events.capacity`).
  final int capacity;

  /// Seats already taken, counted by the view.
  final int registeredCount;

  /// Link to the event's banner or logo in Supabase Storage.
  /// Null when the organizer did not upload one.
  final String? imageUrl;

   /// Full text shown under "About this event" (`events.description`).
  /// Null when the organizer left it empty.
  final String? description;

  /// When the event ends, built from `event_date` + `end_time`.
  /// Null when the organizer gave no end time. Assumes the event ends
  /// on the same day it starts.
  final DateTime? endsAt;

  /// Club or department hosting the event (`events.hosting_org`).
  final String hostingOrg;

  const Event({
    required this.id,
    required this.title,
    required this.categories,
    required this.startsAt,
    required this.venue,
    required this.capacity,
    required this.registeredCount,
    this.imageUrl,
    this.description,
    this.endsAt,
    required this.hostingOrg,
  });

  // ------------------------------------------------------------------
  // Derived values
  // ------------------------------------------------------------------

  /// Seats still open. Clamped at 0 so over-registration can never
  /// show a negative number.
  int get spotsLeft => (capacity - registeredCount).clamp(0, capacity);

  /// True when nobody else can register.
  bool get isFull => spotsLeft == 0;

  // ------------------------------------------------------------------
  // Parsing
  // ------------------------------------------------------------------

  /// Builds an [Event] from one row of `event_overview`.
  factory Event.fromMap(Map<String, dynamic> map) {
    // event_date arrives as '2027-03-15', start_time as '10:00:00'.
    // start_time is nullable in the schema, so fall back to midnight.
    final date = map['event_date'] as String;
    final time = (map['start_time'] as String?) ?? '00:00:00';
    // end_time is also nullable in the schema.
    final endTime = map['end_time'] as String?;

    return Event(
      id: map['event_id'] as String,
      title: map['name'] as String,
      // The view returns a Postgres text[] as a JSON list of names.
      categories: List<String>.from(map['categories'] as List? ?? const []),
      startsAt: DateTime.parse('${date}T$time'),
      venue: map['venue'] as String,
      capacity: map['capacity'] as int,
      registeredCount: map['registered_count'] as int,
      imageUrl: map['image_url'] as String?,
      description: map['description'] as String?,
      endsAt: endTime == null ? null : DateTime.parse('${date}T$endTime'),
      hostingOrg: map['hosting_org'] as String,
    );
  }
}