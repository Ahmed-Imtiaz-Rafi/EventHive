import 'package:event_hive/model/common/event_accessory.dart';

/// Which My events tab a registration belongs to.
enum RegistrationTab { upcoming, past, cancelled }

/// One add-on the student picked, with the price at that moment
/// (`registration_item`).
class RegistrationItem {
  final String name;

  /// Size label from the database, e.g. 'm', or [kOneSize].
  final String size;
  final int quantity;
  final double unitPrice;

  const RegistrationItem({
    required this.name,
    required this.size,
    required this.quantity,
    required this.unitPrice,
  });

  /// 'T-shirt (M)', 'Lunch', or 'Mug ×2'.
  String get label {
    final sized = size == kOneSize ? '' : ' (${formatSize(size)})';
    final times = quantity > 1 ? ' ×$quantity' : '';
    return '$name$sized$times';
  }

  factory RegistrationItem.fromMap(Map<String, dynamic> map) {
    return RegistrationItem(
      name: map['accessory_name'] as String,
      size: map['size'] as String,
      quantity: (map['quantity'] as num).toInt(),
      // NUMERIC can arrive as a number or as text, so convert through text.
      unitPrice: double.parse(map['unit_price'].toString()),
    );
  }
}

/// One of the student's registrations with the event it belongs to.
///
/// Built from a `registration` row (with its `events` row embedded) plus
/// numbers from `registration_balance`. [items] is filled only by the
/// detail query, not by the list.
class MyRegistration {
  final String registrationId;
  final String eventId;
  final String eventTitle;
  final DateTime eventStartsAt;
  final String venue;
  final String? imageUrl;

  /// 'active' or 'cancelled' (the event, not the registration).
  final String eventStatus;

  /// 'pending', 'confirmed', 'cancelled' or 'refunded'.
  final String status;

  /// 'unpaid', 'paid' or 'refund_pending'.
  final String paymentStatus;
  final String roleName;
  final String? trackName;
  final double total;
  final double remaining;
  /// Money an organizer has verified so far (BDT).
  final double paid;

  /// Payments submitted and not yet reviewed.
  final int waitingCount;
  final DateTime? expiresAt;
  final List<RegistrationItem> items;

  const MyRegistration({
    required this.registrationId,
    required this.eventId,
    required this.eventTitle,
    required this.eventStartsAt,
    required this.venue,
    required this.imageUrl,
    required this.eventStatus,
    required this.status,
    required this.paymentStatus,
    required this.roleName,
    required this.trackName,
    required this.total,
    required this.remaining,
    required this.paid,
    required this.waitingCount,
    required this.expiresAt,
    this.items = const [],
  });

  /// Still pending, but the payment window has ended and no payment is
  /// waiting. The database cancels these later; the app treats them as
  /// cancelled now.
  bool get isExpired =>
      status == 'pending' &&
      waitingCount == 0 &&
      expiresAt != null &&
      expiresAt!.isBefore(DateTime.now());

  /// True when the registration is no longer alive for any reason.
  bool get isDead =>
      status == 'cancelled' ||
      status == 'refunded' ||
      eventStatus == 'cancelled' ||
      isExpired;

  /// The My events tab this registration is listed under.
  RegistrationTab get tab {
    if (isDead) return RegistrationTab.cancelled;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(
      eventStartsAt.year,
      eventStartsAt.month,
      eventStartsAt.day,
    );
    return eventDay.isBefore(today)
        ? RegistrationTab.past
        : RegistrationTab.upcoming;
  }

  /// Short label for the chip on a card.
  String get statusLabel {
    if (status == 'confirmed') return 'Confirmed';
    if (status == 'refunded') return 'Refunded';
    if (isDead) {
      return paymentStatus == 'refund_pending' ? 'Refund pending' : 'Cancelled';
    }
    return waitingCount > 0 ? 'In review' : 'Pending';
  }

  /// Text for the "Payment status" row.
  String get paymentLabel {
    if (total == 0) return 'Free';
    if (paymentStatus == 'paid') return 'Paid';
    if (paymentStatus == 'refund_pending') return 'Refund pending';
    return waitingCount > 0 ? 'In review' : 'Unpaid';
  }

  /// Role, with the track when there is one: 'Performer · Music'.
  String get roleLabel =>
      trackName == null ? roleName : '$roleName · $trackName';

  /// The add-ons as one line, or 'None'.
  String get addOnsLabel =>
      items.isEmpty ? 'None' : items.map((i) => i.label).join(', ');

  /// Builds a [MyRegistration] from a `registration` row with its
  /// `events` row embedded, and the matching `registration_balance` row
  /// (null when it is not available).
  factory MyRegistration.fromMaps(
    Map<String, dynamic> reg,
    Map<String, dynamic>? balance, {
    List<RegistrationItem> items = const [],
  }) {
    final event = reg['events'] as Map<String, dynamic>;

    // event_date arrives as '2027-03-15', start_time as '10:00:00'.
    // start_time is nullable, so fall back to midnight.
    final date = event['event_date'] as String;
    final time = (event['start_time'] as String?) ?? '00:00:00';

    final total = double.parse(reg['total_amount'].toString());
    final expires = reg['expires_at'] as String?;

    return MyRegistration(
      registrationId: reg['registration_id'] as String,
      eventId: event['event_id'] as String,
      eventTitle: event['name'] as String,
      eventStartsAt: DateTime.parse('${date}T$time'),
      venue: event['venue'] as String,
      imageUrl: event['image_url'] as String?,
      eventStatus: event['status'] as String,
      status: reg['status'] as String,
      paymentStatus: reg['payment_status'] as String,
      roleName: reg['role_name'] as String,
      trackName: reg['track_name'] as String?,
      total: total,
      remaining: balance == null
          ? total
          : double.parse(balance['remaining_amount'].toString()),
      paid: balance == null
          ? 0
          : double.parse(balance['paid_amount'].toString()),
      waitingCount: balance == null
          ? 0
          : (balance['waiting_count'] as num).toInt(),
      expiresAt: expires == null ? null : DateTime.parse(expires).toLocal(),
      items: items,
    );
  }
}