/// The size value used for add-ons that have no sizes
/// (`accessory_size` enum label in the database).
const kOneSize = 'one_size';

/// Display text for a size label: 'm' becomes 'M', 'one_size' becomes
/// 'One size'.
String formatSize(String size) => size == kOneSize ? 'One size' : size.toUpperCase();

/// One size of an add-on with its own price, e.g. size 'xl' at 550.
class AccessoryOption {
  /// Size label from the database: 'xs', 's', 'm', 'l', 'xl', 'xxl',
  /// 'xxxl' or [kOneSize].
  final String size;

  /// Price in BDT for this size.
  final double price;

  const AccessoryOption({required this.size, required this.price});
}

/// One optional add-on an event offers: merchandise, food, a
/// certificate and so on.
///
/// The `event_accessories` table has one row per add-on AND size, each
/// with its own price. This class is the grouped view of those rows: one
/// add-on with a list of [options]. It lives in `model/common` because
/// organizers will also use it.
class EventAccessory {
  /// Add-on name, typed by the organizer, e.g. 'T-shirt'.
  final String name;

  /// One line explaining the add-on. Null when the organizer left it out.
  final String? description;

  /// The sizes on offer, each with its price. Never empty. An add-on
  /// without sizes has a single option with size [kOneSize].
  final List<AccessoryOption> options;

  const EventAccessory({
    required this.name,
    this.description,
    required this.options,
  });

  /// The real sizes to choose from, without [kOneSize].
  List<String> get sizes => [
    for (final o in options)
      if (o.size != kOneSize) o.size,
  ];

  /// True when the participant must pick a size for this add-on.
  bool get needsSize => sizes.isNotEmpty;

  /// Cheapest option.
  double get lowestPrice =>
      options.map((o) => o.price).reduce((a, b) => a < b ? a : b);

  /// Most expensive option.
  double get highestPrice =>
      options.map((o) => o.price).reduce((a, b) => a > b ? a : b);

  /// True when different sizes cost different amounts.
  bool get hasPriceRange => lowestPrice != highestPrice;

  /// True when every option costs nothing.
  bool get isFree => highestPrice == 0;

  /// Price for the chosen [size]. When no size is chosen yet (or the
  /// add-on has none), this is the lowest price.
  double priceFor(String? size) {
    for (final o in options) {
      if (o.size == size) return o.price;
    }
    return lowestPrice;
  }

  /// Groups `event_accessories` rows (one per add-on and size) into
  /// add-ons. Rows must already be sorted by name; the order of the
  /// add-ons and of their sizes is kept.
  static List<EventAccessory> fromRows(List<Map<String, dynamic>> rows) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      grouped.putIfAbsent(row['accessory_name'] as String, () => []).add(row);
    }

    return [
      for (final entry in grouped.entries)
        EventAccessory(
          name: entry.key,
          description: _firstDescription(entry.value),
          options: [
            for (final row in entry.value)
              AccessoryOption(
                size: row['size'] as String,
                // NUMERIC can arrive as a number or as text, so convert
                // through text to be safe.
                price: double.parse(row['price'].toString()),
              ),
          ],
        ),
    ];
  }

  /// The first non-blank description among an add-on's rows.
  static String? _firstDescription(List<Map<String, dynamic>> rows) {
    for (final row in rows) {
      final text = (row['description'] as String?)?.trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }
}