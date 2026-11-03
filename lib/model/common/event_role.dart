/// One role a participant can register as for an event, with its fee.
///
/// Plain data class, like `Event`. It lives in `model/common` because
/// organizers also create and edit roles. It maps one row of
/// `event_role_price`, plus the tracks from `event_role_track`.
class EventRole {
  /// Role name, display-ready, e.g. 'Participant' or 'Poster Presenter'
  /// (`event_role_price.role_name`).
  final String name;

  /// One line explaining the role. Null when the organizer left it out.
  final String? description;

  /// Fee in BDT. Zero means the role is free.
  final double price;

  /// Tracks the participant must choose from, e.g. ['Music', 'Poetry'].
  /// Empty when the role has no tracks.
  final List<String> tracks;

  const EventRole({
    required this.name,
    this.description,
    required this.price,
    this.tracks = const [],
  });

  /// True when registering as this role costs nothing.
  bool get isFree => price == 0;

  /// True when the participant must also choose a track.
  bool get hasTracks => tracks.isNotEmpty;

  /// Builds an [EventRole] from one row of `event_role_price`. The tracks
  /// come from a separate table, so the caller passes them in.
  factory EventRole.fromMap(
    Map<String, dynamic> map, {
    List<String> tracks = const [],
  }) {
    return EventRole(
      name: map['role_name'] as String,
      description: map['description'] as String?,
      // NUMERIC can arrive as a number or as text, so convert through
      // text to be safe.
      price: double.parse(map['price'].toString()),
      tracks: tracks,
    );
  }
}