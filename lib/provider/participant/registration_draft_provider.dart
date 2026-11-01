import 'package:event_hive/model/common/event_accessory.dart';
import 'package:event_hive/model/common/event_role.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Everything the participant has chosen so far while registering: the
/// event, the role (and track), the add-ons and the size of each add-on
/// that has sizes. Nothing is saved until "Proceed to payment" calls
/// `register_for_event`.
class RegistrationDraft {
  /// Event this draft belongs to. Null before registration starts.
  final String? eventId;

  /// The chosen role, with its fee.
  final EventRole? role;

  /// The chosen track, when the role has tracks.
  final String? trackName;

  /// Names of the selected add-ons.
  final Set<String> accessories;

  /// Chosen size per add-on name, e.g. {'T-shirt': 'm'}.
  final Map<String, String> sizes;

  const RegistrationDraft({
    this.eventId,
    this.role,
    this.trackName,
    this.accessories = const {},
    this.sizes = const {},
  });

  RegistrationDraft copyWith({
    Set<String>? accessories,
    Map<String, String>? sizes,
  }) {
    return RegistrationDraft(
      eventId: eventId,
      role: role,
      trackName: trackName,
      accessories: accessories ?? this.accessories,
      sizes: sizes ?? this.sizes,
    );
  }

  /// Full price so far: the role's fee plus each ticked add-on at the
  /// price of its chosen size. [available] is the event's add-on list.
  /// This is for display only; the database computes the real total.
  double total(List<EventAccessory> available) {
    final addOns = available
        .where((a) => accessories.contains(a.name))
        .fold<double>(0, (sum, a) => sum + a.priceFor(sizes[a.name]));
    return (role?.price ?? 0) + addOns;
  }

  /// The chosen add-ons in the shape `register_for_event` expects:
  /// name, size (omitted for add-ons without sizes) and quantity.
  List<Map<String, dynamic>> toItems() => [
    for (final name in accessories)
      {
        'name': name,
        if (sizes[name] != null) 'size': sizes[name],
        'quantity': 1,
      },
  ];
}

class RegistrationDraftNotifier extends Notifier<RegistrationDraft> {
  @override
  RegistrationDraft build() => const RegistrationDraft();

  /// Called by Select role. For the same event it keeps the add-ons, so
  /// going back to pick another role does not lose them. For another
  /// event it starts a clean draft.
  void selectRole(String eventId, EventRole role, {String? trackName}) {
    state = state.eventId == eventId
        ? RegistrationDraft(
            eventId: eventId,
            role: role,
            trackName: trackName,
            accessories: state.accessories,
            sizes: state.sizes,
          )
        : RegistrationDraft(eventId: eventId, role: role, trackName: trackName);
  }

  /// Selects the add-on, or unselects it if it is already selected.
  void toggleAccessory(String name) {
    final next = {...state.accessories};
    // remove returns true when the name was there; otherwise add it.
    if (!next.remove(name)) next.add(name);

    // An add-on that is dropped also forgets its size.
    final sizes = {...state.sizes}..removeWhere((key, _) => !next.contains(key));

    state = state.copyWith(accessories: next, sizes: sizes);
  }

  /// Stores the size chosen for one add-on.
  void setSize(String accessory, String size) {
    state = state.copyWith(sizes: {...state.sizes, accessory: size});
  }

  /// Forgets everything. Called once the registration has been saved.
  void clear() => state = const RegistrationDraft();
}

final registrationDraftProvider =
    NotifierProvider<RegistrationDraftNotifier, RegistrationDraft>(
      RegistrationDraftNotifier.new,
    );