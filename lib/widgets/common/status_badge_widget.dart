import 'package:flutter/material.dart';

/// Coloured pill showing an event's effective status.
///
/// Pass [eventDate] (ISO string e.g. "2026-11-14") to get a date-aware label:
///   Finished  — event_date is before today          (grey-brown)
///   Ongoing   — event_date is today                 (blue)
///   Upcoming  — event_date is in the future         (amber)
///   Cancelled — status == 'cancelled'               (red)
///
/// Without [eventDate] the raw status string is shown.
class StatusBadge extends StatelessWidget {
  final String status;
  final String? eventDate;

  const StatusBadge({super.key, required this.status, this.eventDate});

  /// Returns (label, background colour, text colour).
  (String, Color, Color) get _resolved {
    // Cancelled always wins regardless of date
    if (status.toLowerCase() == 'cancelled') {
      return ('Cancelled', const Color(0xFFFFE0E0), const Color(0xFFD32F2F));
    }

    if (eventDate != null && eventDate!.isNotEmpty) {
      final date = DateTime.tryParse(eventDate!);
      if (date != null) {
        final today = DateUtils.dateOnly(DateTime.now());
        final eventDay = DateUtils.dateOnly(date);

        if (eventDay.isBefore(today)) {
          // Date has passed
          return ('Finished', const Color(0xFFF0E6D3), const Color(0xFF8B5E00));
        } else if (eventDay.isAtSameMomentAs(today)) {
          // Happening today
          return ('Ongoing', const Color(0xFFDCEEFF), const Color(0xFF1A55CC));
        } else {
          // Future date
          return ('Upcoming', const Color(0xFFFFF3D4), const Color(0xFFB87800));
        }
      }
    }

    // Fallback: use raw status
    if (status.toLowerCase() == 'active') {
      return ('Active', const Color(0xFFD4F4DD), const Color(0xFF1A7A3A));
    }
    return (status, const Color(0xFFE3EEFF), const Color(0xFF1A55CC));
  }

  @override
  Widget build(BuildContext context) {
    final (label, bg, textColor) = _resolved;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: textColor, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
