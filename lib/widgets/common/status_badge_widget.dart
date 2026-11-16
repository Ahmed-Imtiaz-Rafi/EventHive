import 'package:flutter/material.dart';

/// Coloured pill showing an event's effective status.
/// Pass [eventDate] so past active events show "Ended" instead of "Active".
class StatusBadge extends StatelessWidget {
  final String status;
  final String? eventDate; // ISO date string, e.g. "2026-11-14"

  const StatusBadge({super.key, required this.status, this.eventDate});

  /// Returns the label and colours based on status + date.
  (String, Color, Color) get _resolved {
    // A finished event whose DB status is still 'active'
    final isPast = eventDate != null &&
        DateTime.tryParse(eventDate!)
            ?.isBefore(DateTime.now().subtract(const Duration(days: 0))) ==
            true &&
        status.toLowerCase() == 'active';

    if (isPast) {
      return ('Ended', const Color(0xFFF0E6D3), const Color(0xFF8B5E00));
    }
    switch (status.toLowerCase()) {
      case 'active':
        return ('Active', const Color(0xFFD4F4DD), const Color(0xFF1A7A3A));
      case 'cancelled':
        return ('Cancelled', const Color(0xFFFFE0E0), const Color(0xFFD32F2F));
      default:
        return (status, const Color(0xFFE3EEFF), const Color(0xFF1A55CC));
    }
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
