import 'package:event_hive/core/theme/app_theme.dart';
import 'package:event_hive/core/utils/event_date_time_format.dart';
import 'package:event_hive/model/common/event.dart';
import 'package:flutter/material.dart';

/// White card showing one event: thumbnail, title, category tags,
/// date / time / venue, and how many spots are left. Lifts slightly
/// when the mouse hovers over it.
///
/// It lives in `widgets` (not inside a screen) because other screens
/// will reuse it, for example "My events". It takes plain data and has
/// no providers, so it works anywhere.
class EventCard extends StatelessWidget {
  final Event event;

  /// Fallback color for the thumbnail, used when the event has no image.
  final Color accent;

  /// Called when the card is tapped. Null makes the card non-tappable.
  final VoidCallback? onTap;

  const EventCard({
    super.key,
    required this.event,
    required this.accent,
    this.onTap,
  });


  @override
  Widget build(BuildContext context) {
    return _HoverLift(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- Thumbnail ----
            // The event's image when it has one; otherwise (or if the
            // image fails to load) the plain colored square. ClipRRect
            // rounds the image's corners to match the placeholder.
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 56,
                height: 56,
                child: event.imageUrl == null
                    ? ColoredBox(color: accent)
                    : Image.network(
                        event.imageUrl!,
                        // cover = fill the square, cropping the edges.
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => ColoredBox(color: accent),
                      ),
              ),
            ),
            const SizedBox(width: 12),

            // ---- Text column ----
            // Expanded gives the text all the width the thumbnail leaves,
            // so long titles wrap instead of overflowing.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title on its own line, so it keeps the full width.
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'serif',
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: kTextMain,
                    ),
                  ),

                  // One tag per category. Wrap moves tags to the next
                  // line when they don't fit, so any number works.
                  // Hidden when the event has no categories.
                  if (event.categories.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final name in event.categories)
                          _CategoryTag(name),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '${formatEventDate(event.startsAt)} · '
                    '${formatEventTime(event.startsAt)} · ${event.venue}',
                    style: const TextStyle(fontSize: 12, color: kTextSub),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.isFull
                        ? 'Full'
                        : '${event.spotsLeft} / ${event.capacity} spots left',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: kAmber,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small rounded label for one category, e.g. 'Workshop'.
class _CategoryTag extends StatelessWidget {
  final String label;
  const _CategoryTag(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: kTextSub),
      ),
    );
  }
}

/// Wraps a card with a hover effect: it lifts 4 px, gets a soft shadow,
/// and the mouse cursor becomes a pointer (only when it is tappable).
///
/// It is a [StatefulWidget] because it remembers one thing: whether the
/// mouse is currently over it. Keeping this out of [EventCard] lets the
/// card itself stay stateless. Hover only exists with a mouse, so on a
/// phone this widget behaves like a plain tap area.
class _HoverLift extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _HoverLift({required this.child, this.onTap});

  @override
  State<_HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<_HoverLift> {
  /// True while the mouse pointer is over the card.
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        // AnimatedContainer animates between the two states, so the
        // lift and the shadow ease in and out instead of snapping.
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: _hovered
                ? const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ]
                : const [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}