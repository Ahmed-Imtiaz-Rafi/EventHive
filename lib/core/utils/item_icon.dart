import 'package:flutter/material.dart';

/// Picks an icon for a role or an add-on from its name.
///
/// The schema has no icon column, and organizers type any name they
/// like, so the name is split into words and checked against the rules
/// below. The first matching rule wins; a name that matches nothing
/// gets [fallback].
///
/// Whole words are matched (and simple plurals such as "caps"), so
/// "cap" does not match "capture". To support a new kind of item, add
/// its keywords to [_iconRules]; no other file needs to change.
IconData iconForName(
  String name, {
  IconData fallback = Icons.add_box_outlined,
}) {
  // 'T-shirt (M)' becomes {'t', 'shirt', 'm'}.
  final words = name
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((w) => w.isNotEmpty)
      .toSet();

  for (final (keywords, icon) in _iconRules) {
    final matches = keywords.any(
      (k) => words.contains(k) || words.contains('${k}s'),
    );
    if (matches) return icon;
  }
  return fallback;
}

/// Keyword rules, checked from top to bottom.
const List<(List<String>, IconData)> _iconRules = [
  // ---- Add-ons: things to wear (Material has no cap or hat icon,
  // so clothing items share the hanger) ----
  (
    ['shirt', 'tshirt', 'tee', 'hoodie', 'jacket', 'polo', 'jersey', 'cap', 'hat', 'beanie', 'uniform'],
    Icons.checkroom_outlined,
  ),

  // ---- Add-ons: food and drink ----
  (
    ['lunch', 'dinner', 'breakfast', 'meal', 'food', 'snack', 'buffet', 'refreshment', 'feast'],
    Icons.restaurant_outlined,
  ),
  (['coffee', 'tea', 'drink', 'beverage', 'mug', 'cup'], Icons.local_cafe_outlined),
  (['bottle', 'water'], Icons.local_drink_outlined),

  // ---- Add-ons: recognition ----
  (['certificate', 'certification', 'diploma'], Icons.workspace_premium_outlined),
  (['trophy', 'medal', 'award', 'prize'], Icons.emoji_events_outlined),

  // ---- Add-ons: goodies ----
  (['bag', 'tote', 'backpack', 'kit', 'goodie', 'goodies'], Icons.shopping_bag_outlined),
  (['gift', 'hamper', 'souvenir', 'giveaway'], Icons.card_giftcard_outlined),
  (['book', 'handbook', 'guide', 'notebook', 'diary'], Icons.menu_book_outlined),
  (['pen', 'pencil', 'stationery'], Icons.edit_outlined),
  (['sticker', 'stickers'], Icons.sticky_note_2_outlined),

  // ---- Add-ons: access and services ----
  (['ticket', 'entry', 'vip', 'pass'], Icons.confirmation_number_outlined),
  (['badge', 'lanyard', 'id'], Icons.badge_outlined),
  (['bus', 'shuttle', 'transport', 'pickup'], Icons.directions_bus_outlined),
  (['parking'], Icons.local_parking_outlined),
  (['hotel', 'accommodation', 'stay', 'hostel', 'lodging'], Icons.hotel_outlined),
  (['photo', 'photos', 'photography', 'album', 'camera'], Icons.photo_camera_outlined),
  (['video', 'recording', 'stream', 'replay'], Icons.videocam_outlined),
  (['workshop', 'training', 'course', 'class', 'session', 'masterclass'], Icons.school_outlined),
  (['stall', 'booth', 'exhibit', 'exhibition', 'sponsor'], Icons.storefront_outlined),

  // ---- Roles ----
  (['participant', 'attendee', 'delegate', 'student', 'competitor'], Icons.person_outline),
  (['performer', 'speaker', 'singer', 'dancer', 'artist', 'presenter', 'host'], Icons.mic_none_outlined),
  (['guest', 'audience', 'visitor', 'spectator'], Icons.groups_outlined),
  (['judge', 'jury', 'mentor'], Icons.gavel_outlined),
  (['volunteer', 'helper'], Icons.volunteer_activism_outlined),
];