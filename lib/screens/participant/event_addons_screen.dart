import 'package:event_hive/core/theme/app_theme.dart';
import 'package:event_hive/core/utils/item_icon.dart';
import 'package:event_hive/core/utils/price_format.dart';
import 'package:event_hive/model/common/event_accessory.dart';
import 'package:event_hive/model/common/event_role.dart';
import 'package:event_hive/provider/participant/registration_provider.dart';
import 'package:event_hive/provider/participant/accessory_provider.dart';
import 'package:event_hive/provider/participant/registration_draft_provider.dart';
import 'package:event_hive/widgets/common/app_header_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Second step of registration: the participant picks optional add-ons
/// (merchandise, food, a certificate...) and a size for those that have
/// one, sees the full price, and proceeds to payment.
///
/// The add-ons come from the database through [eventAccessoriesProvider].
/// The role chosen on the previous screen comes from
/// [registrationDraftProvider]. If there is no role (for example the
/// page was refreshed, which clears the draft), the screen sends the
/// participant back to Select role instead of showing a wrong total.
class EventAddonsScreen extends ConsumerWidget {
  /// UUID of the event being registered for (`events.event_id`).
  final String eventId;

  const EventAddonsScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(registrationDraftProvider);
    // Only trust the draft if it belongs to this event.
    final role = draft.eventId == eventId ? draft.role : null;

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppHeaderBar(
                title: 'Event add-ons',
                // Without a previous screen, go back to choosing a role.
                fallbackRoute: '/participant/event/$eventId/role',
              ),
              const SizedBox(height: 16),
              Expanded(
                child: role == null
                    ? _MissingRole(eventId: eventId)
                    : _AddonsContent(eventId: eventId, role: role),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------
// Content
// ------------------------------------------------------------------

/// Shown when no role has been chosen for this event.
class _MissingRole extends StatelessWidget {
  final String eventId;
  const _MissingRole({required this.eventId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Choose a role first.', style: TextStyle(color: kTextSub)),
          const SizedBox(height: 12),
          ElevatedButton(
            // go replaces the stack, so there is no stale add-ons page
            // left behind it.
            onPressed: () => context.go('/participant/event/$eventId/role'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kNavy,
              foregroundColor: Colors.white,
            ),
            child: const Text('Select role'),
          ),
        ],
      ),
    );
  }
}

/// Add-on list, size pickers, price breakdown, and the total with the
/// Proceed button. Everything scrolls except the total and the button,
/// which stay at the bottom.
class _AddonsContent extends ConsumerWidget {
  final String eventId;
  final EventRole role;
  const _AddonsContent({required this.eventId, required this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = ref.watch(eventAccessoriesProvider(eventId));
    final draft = ref.watch(registrationDraftProvider);
    final notifier = ref.read(registrationDraftProvider.notifier);

    // The loaded add-ons, or an empty list while loading or on error.
    // maybeWhen is safe in every state; it never throws on errors.
    final all = request.maybeWhen(
      data: (list) => list,
      orElse: () => <EventAccessory>[],
    );

    // The add-ons the participant has ticked.
    final chosen = all
        .where((a) => draft.accessories.contains(a.name))
        .toList();

    // A ticked add-on with sizes is incomplete until a size is chosen.
    final missingSize = chosen.any(
      (a) => a.needsSize && !draft.sizes.containsKey(a.name),
    );

    // Role fee plus each ticked add-on at the price of its chosen size.
    // For display only; the database computes the real total.
    final total = draft.total(all);

    /// 'T-shirt (M)' once a size is chosen, otherwise just the name.
    String lineLabel(EventAccessory a) {
      final size = draft.sizes[a.name];
      return size == null ? a.name : '${a.name} (${formatSize(size)})';
    }

    return Column(
      children: [
        // ---- Scrollable part ----
        Expanded(
          child: request.when(
            // ---- Loading ----
            loading: () => const Center(child: CircularProgressIndicator()),

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
                      // invalidate = throw away the failed result and
                      // fetch again.
                      onPressed: () =>
                          ref.invalidate(eventAccessoriesProvider(eventId)),
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
            data: (list) => ListView(
              children: [
                if (list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: Text(
                      'This event has no add-ons. You can go straight to payment.',
                      style: TextStyle(fontSize: 14, color: kTextSub),
                    ),
                  )
                else ...[
                  const Text(
                    'Enhance your experience with these add-ons',
                    style: TextStyle(fontSize: 14, color: kTextSub),
                  ),
                  const SizedBox(height: 12),
                  for (final a in list) ...[
                    _AddonCard(
                      accessory: a,
                      selected: draft.accessories.contains(a.name),
                      onTap: () => notifier.toggleAccessory(a.name),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],

                // One size picker per ticked add-on that has sizes.
                for (final a in chosen.where((a) => a.needsSize))
                  _SizePicker(
                    label: '${a.name} size',
                    options: [
                      for (final o in a.options)
                        if (o.size != kOneSize) o,
                    ],
                    // Show each size's price only when they differ.
                    showPrices: a.hasPriceRange,
                    selected: draft.sizes[a.name],
                    onSelected: (size) => notifier.setSize(a.name, size),
                  ),

                // ---- Price breakdown ----
                const Divider(color: kBorder),
                const SizedBox(height: 8),
                _PriceLine(label: '${role.name} (role)', price: role.price),
                for (final a in chosen)
                  _PriceLine(
                    label: lineLabel(a),
                    price: a.priceFor(draft.sizes[a.name]),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),

        // ---- Fixed bottom: total and Proceed ----
        const Divider(color: kBorder),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: kTextMain,
              ),
            ),
            Text(
              formatBdt(total),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: kTextMain,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ProceedButton(
          eventId: eventId,
          total: total,
          // Enabled once the add-ons have loaded and every ticked add-on
          // that needs a size has one.
          enabled: request.hasValue && !missingSize,
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------
// Add-on card
// ------------------------------------------------------------------

/// One selectable add-on: icon, name, description, price and a
/// checkbox. The selected card gets a navy border, a navy icon square
/// and a ticked box. When sizes cost different amounts, the price reads
/// "From 500 BDT".
class _AddonCard extends StatelessWidget {
  final EventAccessory accessory;
  final bool selected;
  final VoidCallback onTap;

  const _AddonCard({
    required this.accessory,
    required this.selected,
    required this.onTap,
  });

  /// 'Free', '500 BDT', or 'From 500 BDT' when sizes differ in price.
  String _priceText() {
    if (accessory.isFree) return 'Free';
    final lowest = formatBdt(accessory.lowestPrice);
    return accessory.hasPriceRange ? 'From $lowest' : lowest;
  }

  @override
  Widget build(BuildContext context) {
    final description = accessory.description?.trim();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(16),
            // Same width in both states, so the card never shifts.
            border: Border.all(color: selected ? kNavy : kBorder, width: 1.5),
          ),
          child: Row(
            children: [
              // ---- Icon square ----
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? kNavy : kBorder,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  iconForName(accessory.name),
                  size: 22,
                  color: selected ? Colors.white : kTextSub,
                ),
              ),
              const SizedBox(width: 12),

              // ---- Name, description, price ----
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
                  ],
                ),
              ),
              const SizedBox(width: 12),

              _CheckBox(checked: selected),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded square marker: empty, or navy with a tick when checked.
/// Drawn by hand to match the design.
class _CheckBox extends StatelessWidget {
  final bool checked;
  const _CheckBox({required this.checked});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: checked ? kNavy : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: checked ? kNavy : kBorder, width: 2),
      ),
      child: checked
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : null,
    );
  }
}

// ------------------------------------------------------------------
// Size picker
// ------------------------------------------------------------------

/// Row of size buttons for one add-on, for example "T-shirt size".
/// Shows a reminder until a size is chosen, and each size's price when
/// [showPrices] is true.
class _SizePicker extends StatelessWidget {
  final String label;
  final List<AccessoryOption> options;
  final bool showPrices;

  /// Database label of the chosen size, e.g. 'm', or null.
  final String? selected;
  final ValueChanged<String> onSelected;

  const _SizePicker({
    required this.label,
    required this.options,
    required this.showPrices,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: kTextSub)),
          const SizedBox(height: 8),
          // Wrap moves buttons to the next line on narrow screens.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                _SizeChip(
                  label: formatSize(option.size),
                  caption: showPrices ? formatBdt(option.price) : null,
                  selected: option.size == selected,
                  onTap: () => onSelected(option.size),
                ),
            ],
          ),
          if (selected == null) ...[
            const SizedBox(height: 6),
            const Text(
              'Choose a size to continue',
              style: TextStyle(fontSize: 12, color: kAmber),
            ),
          ],
        ],
      ),
    );
  }
}

/// One size button: navy when selected, white otherwise, with an
/// optional small price underneath.
class _SizeChip extends StatelessWidget {
  final String label;
  final String? caption;
  final bool selected;
  final VoidCallback onTap;

  const _SizeChip({
    required this.label,
    required this.caption,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? kNavy : kSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? kNavy : kBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : kTextMain,
                ),
              ),
              if (caption != null)
                Text(
                  caption!,
                  style: TextStyle(
                    fontSize: 10,
                    color: selected ? Colors.white70 : kTextSub,
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
// Price breakdown
// ------------------------------------------------------------------

/// One line of the breakdown: a label on the left and its price on
/// the right.
class _PriceLine extends StatelessWidget {
  final String label;
  final double price;
  const _PriceLine({required this.label, required this.price});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Expanded lets a long name wrap instead of overflowing.
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: kTextSub),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            price == 0 ? 'Free' : formatBdt(price),
            style: const TextStyle(fontSize: 14, color: kTextMain),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------
// Proceed button
// ------------------------------------------------------------------

/// Saves the registration, then opens the payment screen.
///
/// Registering creates the registration in the database (it holds a seat
/// for one day), so this is the point where the choices become real. A
/// free total is confirmed at once and shows the confirmation instead of
/// asking for money. If the participant already has a registration for
/// this event, it is opened instead of showing an error.
class _ProceedButton extends ConsumerStatefulWidget {
  final String eventId;
  final double total;
  final bool enabled;

  const _ProceedButton({
    required this.eventId,
    required this.total,
    required this.enabled,
  });

  @override
  ConsumerState<_ProceedButton> createState() => _ProceedButtonState();
}

class _ProceedButtonState extends ConsumerState<_ProceedButton> {
  /// True while the registration is being saved; stops double taps.
  bool _busy = false;

  Future<void> _proceed() async {
    final draft = ref.read(registrationDraftProvider);
    final role = draft.role;
    if (role == null) return;

    final actions = ref.read(registrationActionsProvider);
    // Keep the notifier: the screen will be gone when it is needed.
    final draftNotifier = ref.read(registrationDraftProvider.notifier);

    setState(() => _busy = true);
    try {
      final id = await actions.register(
        eventId: widget.eventId,
        roleName: role.name,
        items: draft.toItems(),
        trackName: draft.trackName,
      );
      if (!mounted) return;

      // My events shows the new registration.
      ref.invalidate(myRegistrationsProvider);

      // go replaces the stack: the choices are saved, so Back must not
      // return to them. The draft is cleared after the screen is gone.
      context.go('/participant/my-events/registration/$id');
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => draftNotifier.clear(),
      );
    } on RegistrationException catch (e) {
      if (!mounted) return;

      // Already registered: continue with that registration.
      if (e.code == 'ALREADY_REGISTERED') {
        final existing = await actions.findLiveRegistrationId(widget.eventId);
        if (!mounted) return;
        if (existing != null) {
          context.go('/participant/my-events/registration/$existing');
          return;
        }
      }

      _showMessage(
        e.message,
        // An incomplete profile can be fixed on the Profile tab.
        action: e.code == 'PROFILE_INCOMPLETE'
            ? SnackBarAction(
                label: 'Profile',
                onPressed: () => context.push('/participant/profile/edit'),
              )
            : null,
      );
    } catch (e) {
      debugPrint('Unexpected error while registering: $e');
      if (mounted) {
        _showMessage('Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String text, {SnackBarAction? action}) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text), action: action));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        // null = disabled while saving or until the choices are complete.
        onPressed: (!widget.enabled || _busy) ? null : _proceed,
        style: ElevatedButton.styleFrom(
          backgroundColor: kAmber,
          foregroundColor: Colors.white,
          disabledBackgroundColor: kAmber.withValues(alpha: 0.5),
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                // A free registration has no payment step.
                widget.total == 0 ? 'Register' : 'Proceed to payment',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
