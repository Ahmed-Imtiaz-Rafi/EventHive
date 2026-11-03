import 'package:event_hive/core/theme/app_theme.dart';
import 'package:event_hive/core/utils/item_icon.dart';
import 'package:event_hive/core/utils/price_format.dart';
import 'package:event_hive/model/common/event_accessory.dart';
import 'package:event_hive/provider/participant/accessory_provider.dart';
import 'package:event_hive/widgets/common/app_header_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Read-only list of what an event offers as add-ons, opened by
/// "View add-ons" on Event Details.
///
/// Anyone can look without registering: nothing here can be selected and
/// no role is needed. Add-ons with sizes show every size, with its price
/// when the sizes cost different amounts. Choosing add-ons happens later,
/// in the registration flow (`EventAddonsScreen`).
///
/// The add-ons come from the database through [eventAccessoriesProvider],
/// the same provider the registration flow uses.
class EventAddonsPreviewScreen extends ConsumerWidget {
  /// UUID of the event whose add-ons are shown (`events.event_id`).
  final String eventId;

  const EventAddonsPreviewScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = ref.watch(eventAccessoriesProvider(eventId));

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppHeaderBar(
                title: 'Event add-ons',
                // Without a previous screen, go to this event's details.
                fallbackRoute: '/participant/event/$eventId',
              ),
              const SizedBox(height: 16),
              const Text(
                'What this event offers. You can choose add-ons when you register.',
                style: TextStyle(fontSize: 14, color: kTextSub),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: request.when(
                  // ---- Loading ----
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),

                  // ---- Error ----
                  // Details go to the console; the user sees a generic message.
                  error: (e, _) {
                    debugPrint('Failed to load add-ons: $e');
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Could not load add-ons',
                            style: TextStyle(color: kTextSub),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            // invalidate = throw away the failed result
                            // and fetch again.
                            onPressed: () => ref.invalidate(
                              eventAccessoriesProvider(eventId),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kNavy,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  },

                  // ---- Data ----
                  data: (list) {
                    if (list.isEmpty) {
                      return const Center(
                        child: Text(
                          'This event has no add-ons.',
                          style: TextStyle(color: kTextSub),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) =>
                          _AddonInfoCard(accessory: list[i]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------
// Add-on card (read-only)
// ------------------------------------------------------------------

/// One add-on shown for information only: icon, name, description,
/// price and, when it has sizes, the list of sizes. It has no checkbox
/// and no tap handling, so nothing about it can be changed.
class _AddonInfoCard extends StatelessWidget {
  final EventAccessory accessory;
  const _AddonInfoCard({required this.accessory});

  /// 'Free', '500 BDT', or 'From 500 BDT' when sizes differ in price.
  String _priceText() {
    if (accessory.isFree) return 'Free';
    final lowest = formatBdt(accessory.lowestPrice);
    return accessory.hasPriceRange ? 'From $lowest' : lowest;
  }

  @override
  Widget build(BuildContext context) {
    final description = accessory.description?.trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Icon square ----
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: kBorder,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              iconForName(accessory.name),
              size: 22,
              color: kTextSub,
            ),
          ),
          const SizedBox(width: 12),

          // ---- Name, description, price, sizes ----
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  accessory.name,
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kTextMain,
                  ),
                ),
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 12, color: kTextSub),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  _priceText(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: kAmber,
                  ),
                ),

                // Sizes, only for add-ons that have them.
                if (accessory.needsSize) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Available sizes',
                    style: TextStyle(fontSize: 11, color: kTextSub),
                  ),
                  const SizedBox(height: 6),
                  // Wrap moves tags to the next line on narrow screens.
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final option in accessory.options)
                        if (option.size != kOneSize)
                          _SizeTag(
                            label: formatSize(option.size),
                            // Show each size's price only when they differ.
                            price: accessory.hasPriceRange
                                ? formatBdt(option.price)
                                : null,
                          ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small non-clickable label for one size, e.g. 'XL' or 'XL · 550 BDT'.
class _SizeTag extends StatelessWidget {
  final String label;
  final String? price;
  const _SizeTag({required this.label, required this.price});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Text(
        price == null ? label : '$label · $price',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: kTextMain,
        ),
      ),
    );
  }
}