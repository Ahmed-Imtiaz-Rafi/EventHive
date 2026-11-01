import 'package:event_hive/model/common/payment_account.dart';
import 'package:event_hive/model/common/registration_balance.dart';
import 'package:event_hive/model/common/my_registration.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ------------------------------------------------------------------
// Errors
// ------------------------------------------------------------------

/// Friendly text for the error codes the database functions raise. The
/// database writes errors as 'CODE: details'; the code is matched here.
const _friendly = <String, String>{
  'NOT_SIGNED_IN': 'Please sign in again.',
  'PROFILE_INCOMPLETE':
      'Add your student ID and department in your profile first.',
  'EVENT_NOT_FOUND': 'This event no longer exists.',
  'EVENT_CLOSED': 'Registration for this event is closed.',
  'NOT_ELIGIBLE': 'This event is only open to certain departments.',
  'EVENT_FULL': 'Sorry, this event is full.',
  'ROLE_NOT_OFFERED': 'This role is not offered for this event.',
  'ROLE_FULL': 'There are no slots left for this role.',
  'TRACK_REQUIRED': 'Choose a track for this role.',
  'INVALID_TRACK': 'That track is not available.',
  'TRACK_FULL': 'There are no slots left in that track.',
  'ALREADY_REGISTERED': 'You already have a registration for this event.',
  'NOT_YOUR_REGISTRATION': 'This registration was not found.',
  'REGISTRATION_EXPIRED':
      'The payment time has ended. Please register again.',
  'DUPLICATE_TRANSACTION': 'This transaction ID has already been used.',
};

/// Codes whose own details are specific enough to show as they are, for
/// example "the transaction ID looks invalid".
const _useServerText = {
  'INVALID_PAYMENT',
  'INVALID_REGISTRATION',
  'EVENT_CLOSED',
  'PAYMENT_WAITING',
};

/// A registration or payment action that the database refused.
/// [message] is safe to show to the user; [code] is for the code to act on.
class RegistrationException implements Exception {
  final String code;
  final String message;

  const RegistrationException(this.code, this.message);

  /// Turns whatever was thrown into a [RegistrationException]. The raw
  /// error goes to the console; the user only sees [message].
  factory RegistrationException.from(Object error) {
    final raw = error is PostgrestException ? error.message : error.toString();
    debugPrint('Registration error: $raw');

    final match = RegExp(
      r'^([A-Z_]+):\s*(.*)$',
      dotAll: true,
    ).firstMatch(raw.trim());
    if (match == null) {
      return const RegistrationException(
        'UNKNOWN',
        'Something went wrong. Please try again.',
      );
    }

    final code = match.group(1)!;
    final details = match.group(2)!.trim();

    if (_useServerText.contains(code) && details.isNotEmpty) {
      return RegistrationException(
        code,
        '${details[0].toUpperCase()}${details.substring(1)}',
      );
    }
    return RegistrationException(
      code,
      _friendly[code] ?? 'Something went wrong. Please try again.',
    );
  }

  @override
  String toString() => message;
}

// ------------------------------------------------------------------
// Actions
// ------------------------------------------------------------------

/// The things a participant can do to a registration. Every call goes
/// through a database function that re-checks all rules, so the app can
/// never skip them. Failures are thrown as [RegistrationException].
class RegistrationActions {
  SupabaseClient get _client => Supabase.instance.client;

  /// Creates the registration and returns its id.
  ///
  /// The database computes the total from its own prices. A free total
  /// confirms at once; otherwise the registration is pending with a
  /// payment window of one day.
  Future<String> register({
    required String eventId,
    required String roleName,
    required List<Map<String, dynamic>> items,
    String? trackName,
  }) async {
    try {
      final id = await _client.rpc(
        'register_for_event',
        params: {
          'p_event_id': eventId,
          'p_role_name': roleName,
          'p_items': items,
          'p_track_name': trackName,
        },
      );
      return id as String;
    } catch (e) {
      throw RegistrationException.from(e);
    }
  }

  /// Cancels the registration. A registration with money verified becomes
  /// 'refund pending'; the refund itself is handled outside the app.
  /// Refused while a payment is waiting for review.
  Future<void> cancel(String registrationId) async {
    try {
      await _client.rpc(
        'cancel_registration',
        params: {'p_registration_id': registrationId},
      );
    } catch (e) {
      throw RegistrationException.from(e);
    }
  }

  /// Reports a payment the participant made. An organizer verifies it
  /// later; until then the registration stays pending.
  Future<void> submitPayment({
    required String registrationId,
    required int accountId,
    required String transactionId,
    required String reference,
  }) async {
    try {
      await _client.rpc(
        'submit_payment',
        params: {
          'p_registration_id': registrationId,
          'p_account_id': accountId,
          'p_transaction_id': transactionId,
          'p_reference': reference,
        },
      );
    } catch (e) {
      throw RegistrationException.from(e);
    }
  }

  /// The id of the signed-in user's live (pending or confirmed)
  /// registration for the event, or null if there is none.
  Future<String?> findLiveRegistrationId(String eventId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      final rows = await _client
          .from('registration_balance')
          .select('registration_id')
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .inFilter('status', ['pending', 'confirmed'])
          .limit(1);

      final list = rows as List;
      return list.isEmpty ? null : list.first['registration_id'] as String;
    } catch (e) {
      debugPrint('Could not look up the registration: $e');
      return null;
    }
  }
}

final registrationActionsProvider = Provider<RegistrationActions>(
  (ref) => RegistrationActions(),
);

// ------------------------------------------------------------------
// Data
// ------------------------------------------------------------------

/// Where one registration stands, read from `registration_balance`.
/// `autoDispose` so reopening the screen always shows fresh numbers.
final registrationBalanceProvider = FutureProvider.autoDispose
    .family<RegistrationBalance, String>((ref, registrationId) async {
      final row = await Supabase.instance.client
          .from('registration_balance')
          .select()
          .eq('registration_id', registrationId)
          .single();

      return RegistrationBalance.fromMap(row);
    });

/// The active receiving accounts an event accepts: those of its hosting
/// club, each with its method (bKash / Nagad, send money / payment).
/// Empty when the event has no club or the club has no active account.
final paymentAccountsProvider = FutureProvider.autoDispose
    .family<List<PaymentAccount>, String>((ref, eventId) async {
      final client = Supabase.instance.client;

      final event = await client
          .from('events')
          .select('club_id')
          .eq('event_id', eventId)
          .single();
      final clubId = event['club_id'] as int?;
      if (clubId == null) return [];

      final rows = await client
          .from('payment_accounts')
          .select(
            'account_id, account_number, instructions, '
            'payment_methods(provider, kind, label)',
          )
          .eq('club_id', clubId)
          .eq('is_active', true)
          .order('account_id', ascending: true);

      return (rows as List)
          .map((row) => PaymentAccount.fromMap(row as Map<String, dynamic>))
          .toList();
    });

// ------------------------------------------------------------------
// The student's own registrations
// ------------------------------------------------------------------

/// What to read for a registration: its own columns and the event it is
/// for. `events(...)` embeds the related event row.
const _registrationColumns =
    'registration_id, status, payment_status, role_name, track_name, '
    'total_amount, expires_at, '
    'events(event_id, name, event_date, start_time, venue, image_url, status)';

/// All registrations of the logged-in student, newest first, for My
/// events.
///
/// Filtered by user id on purpose: organizers can also read other
/// students' registrations for their events, and those must not show up
/// here. `autoDispose` so another user never sees this list after a
/// logout. Invalidate it after registering or paying.
final myRegistrationsProvider = FutureProvider.autoDispose<
  List<MyRegistration>
>((ref) async {
  final client = Supabase.instance.client;

  final userId = client.auth.currentUser?.id;
  if (userId == null) {
    throw const AuthException('Not signed in');
  }

  final rows = await client
      .from('registration')
      .select(_registrationColumns)
      .eq('user_id', userId)
      .order('registered_at', ascending: false);

  // Money progress comes from the balance view, not from adding payments
  // up by hand.
  final balanceRows = await client
      .from('registration_balance')
      .select('registration_id, paid_amount, remaining_amount, waiting_count')
      .eq('user_id', userId);

  final balances = <String, Map<String, dynamic>>{
    for (final b in (balanceRows as List))
      b['registration_id'] as String: b as Map<String, dynamic>,
  };

  return (rows as List).map((row) {
    final map = row as Map<String, dynamic>;
    return MyRegistration.fromMaps(map, balances[map['registration_id']]);
  }).toList();
});

/// One registration of the logged-in student with the add-ons chosen,
/// for the registration status view.
final registrationDetailsProvider = FutureProvider.autoDispose
    .family<MyRegistration, String>((ref, registrationId) async {
      final client = Supabase.instance.client;

      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        throw const AuthException('Not signed in');
      }

      final row = await client
          .from('registration')
          .select(_registrationColumns)
          .eq('registration_id', registrationId)
          .eq('user_id', userId)
          .single();

      final balance = await client
          .from('registration_balance')
          .select('registration_id, paid_amount, remaining_amount, waiting_count')
          .eq('registration_id', registrationId)
          .maybeSingle();

      final itemRows = await client
          .from('registration_item')
          .select('accessory_name, size, quantity, unit_price')
          .eq('registration_id', registrationId)
          .order('accessory_name', ascending: true);

      return MyRegistration.fromMaps(
        row,
        balance,
        items: (itemRows as List)
            .map((r) => RegistrationItem.fromMap(r as Map<String, dynamic>))
            .toList(),
      );
    });