/// Where one registration stands: its status, what it costs, what has
/// been verified so far, and until when it can be paid.
///
/// One row of the `registration_balance` view, which is the single place
/// the app reads these numbers from (never add payments up by hand).
class RegistrationBalance {
  final String registrationId;
  final String eventId;

  /// 'pending', 'confirmed', 'cancelled' or 'refunded'.
  final String status;

  /// Total fixed when the student registered (BDT).
  final double total;

  /// Sum of the payments an organizer has verified (BDT).
  final double paid;

  /// What is still to pay, never below 0 (BDT).
  final double remaining;

  /// Payments submitted and not yet reviewed.
  final int waitingCount;

  /// End of the payment window. Null when confirmed or free.
  final DateTime? expiresAt;

  const RegistrationBalance({
    required this.registrationId,
    required this.eventId,
    required this.status,
    required this.total,
    required this.paid,
    required this.remaining,
    required this.waitingCount,
    required this.expiresAt,
  });

  bool get isConfirmed => status == 'confirmed';

  /// Cancelled or refunded: nothing more can be paid.
  bool get isClosed => status == 'cancelled' || status == 'refunded';

  /// Still pending but the window has ended and no payment is waiting.
  /// The database cancels these later; the app treats them as closed now.
  bool get isExpired =>
      status == 'pending' &&
      waitingCount == 0 &&
      expiresAt != null &&
      expiresAt!.isBefore(DateTime.now());

  factory RegistrationBalance.fromMap(Map<String, dynamic> map) {
    // NUMERIC can arrive as a number or as text, so convert through text.
    double amount(String key) => double.parse(map[key].toString());
    final expires = map['expires_at'] as String?;

    return RegistrationBalance(
      registrationId: map['registration_id'] as String,
      eventId: map['event_id'] as String,
      status: map['status'] as String,
      total: amount('total_amount'),
      paid: amount('paid_amount'),
      remaining: amount('remaining_amount'),
      waitingCount: (map['waiting_count'] as num).toInt(),
      expiresAt: expires == null ? null : DateTime.parse(expires).toLocal(),
    );
  }
}