import 'package:event_hive/core/theme/app_theme.dart';
import 'package:event_hive/core/utils/event_date_time_format.dart';
import 'package:event_hive/model/common/event.dart';
import 'package:event_hive/provider/participant/event_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Full details of one event, opened by tapping a card on Home.
///
/// Receives only the event's id (from the route) and loads the event
/// itself through [eventDetailsProvider]. Passing the id instead of an
/// `Event` object means the screen also works when the page is
/// refreshed or opened from a link, when no object exists to pass.
class EventDetailsScreen extends ConsumerWidget {
  /// UUID of the event to show (`events.event_id`).
  final String eventId;

  const EventDetailsScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final event = ref.watch(eventDetailsProvider(eventId));

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _DetailsHeader(),
              const SizedBox(height: 16),

              // The header stays visible in every state, so Back always
              // works, even when loading fails.
              Expanded(
                child: event.when(
                  // ---- Loading ----
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),

                  // ---- Error ----
                  // Details go to the console; the user sees a generic message.
                  error: (e, _) {
                    debugPrint('Failed to load event $eventId: $e');
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Could not load this event',
                            style: TextStyle(color: kTextSub),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            // invalidate = throw away the failed result
                            // and fetch again.
                            onPressed: () =>
                                ref.invalidate(eventDetailsProvider(eventId)),
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
                  data: (e) => _EventDetailsBody(event: e),
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
// Header
// ------------------------------------------------------------------

/// Navy bar at the top: back arrow and the "Event details" title.
class _DetailsHeader extends StatelessWidget {
  const _DetailsHeader();

  /// Goes back to the previous screen. If there is none (the page was
  /// refreshed or opened from a link, so the stack is empty), go to
  /// the participant home instead of doing nothing.
  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/participant/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: kNavy,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _goBack(context),
            icon: const Icon(Icons.chevron_left, color: Colors.white),
          ),
          const Text(
            'Event details',
            style: TextStyle(
              fontFamily: 'serif',
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------
// Body
// ------------------------------------------------------------------

/// Scrollable content of the screen: banner, title and info rows.
/// It scrolls as one piece, so tall content never overflows the screen.
class _EventDetailsBody extends StatelessWidget {
  final Event event;
  const _EventDetailsBody({required this.event});

  /// Builds the date and time line: the date, the start time and, when
  /// the organizer set one, the end time.
  String _whenText() {
    final start = event.startsAt;
    final end = event.endsAt;
    final range = end == null
        ? formatEventTime(start)
        : '${formatEventTime(start)} – ${formatEventTime(end)}';
    return '${formatEventDate(start)} · $range';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Banner(imageUrl: event.imageUrl, categories: event.categories),
          const SizedBox(height: 20),
          Text(
            event.title,
            style: const TextStyle(
              fontFamily: 'serif',
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: kTextMain,
            ),
          ),
          const SizedBox(height: 16),
          _InfoRow(icon: Icons.calendar_today_outlined, text: _whenText()),
          _InfoRow(icon: Icons.location_on_outlined, text: event.venue),
          _InfoRow(
            icon: Icons.person_outline,
            text: 'Host: ${event.hostingOrg}',
          ),
          _InfoRow(
            icon: Icons.groups_outlined,
            text: event.isFull
                ? 'Capacity: Full'
                : 'Capacity: ${event.spotsLeft} / ${event.capacity} spots left',
          ),
          const SizedBox(height: 8),
          const Divider(color: kBorder),
          const SizedBox(height: 12),

          // The description is optional in the database, so the whole
          // section is hidden when it is empty.
          if (event.description?.trim().isNotEmpty ?? false) ...[
            const Text(
              'About this event',
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: kTextMain,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              event.description!.trim(),
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: kTextSub,
              ),
            ),
            const SizedBox(height: 24),
          ],

          _ActionButtons(isFull: event.isFull),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Wide banner: the event's image, or a navy gradient when it has none,
/// with the category tags in the top-right corner.
class _Banner extends StatelessWidget {
  final String? imageUrl;
  final List<String> categories;
  const _Banner({required this.imageUrl, required this.categories});

  /// Shown when there is no image, or when the image fails to load.
  static const _placeholder = DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [kNavy, kTextSub],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: double.infinity,
        height: 180,
        // Stack layers the tags on top of the image.
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl == null)
              _placeholder
            else
              Image.network(
                imageUrl!,
                // cover = fill the banner, cropping the edges.
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _placeholder,
              ),
            Positioned(
              top: 12,
              right: 12,
              // Wrap moves extra tags to the next line, right-aligned.
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.end,
                children: [
                  for (final name in categories) _BannerTag(name),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dark translucent label that stays readable on any image.
class _BannerTag extends StatelessWidget {
  final String label;
  const _BannerTag(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: Colors.white),
      ),
    );
  }
}

/// One line of event info: a white rounded icon square and its text.
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kBorder),
            ),
            child: Icon(icon, size: 18, color: kTextMain),
          ),
          const SizedBox(width: 12),
          // Expanded lets long text wrap instead of overflowing.
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: kTextMain),
            ),
          ),
        ],
      ),
    );
  }
}

/// The two main actions of the screen: "View add-ons" and "Register now".
///
/// Both do nothing yet. They are connected once the add-ons and
/// registration flow exists. "Register now" is disabled when the event
/// is full, so nobody can start a registration that cannot succeed.
class _ActionButtons extends StatelessWidget {
  final bool isFull;
  const _ActionButtons({required this.isFull});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: kAmber,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'View add-ons',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            // null disables the button.
            onPressed: isFull ? null : () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: kTextMain,
              side: BorderSide(color: isFull ? kBorder : kNavy, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              isFull ? 'Event full' : 'Register now',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}