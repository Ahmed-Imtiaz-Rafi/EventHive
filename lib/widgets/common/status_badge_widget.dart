import 'package:flutter/material.dart';

// A coloured pill that shows a status label (Active, Cancelled, Upcoming, etc.)
// Used wherever events are displayed — home, my events, manage event, etc.
class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color text;

    switch (status.toLowerCase()) {
      case 'active':
        bg = const Color(0xFFD4F4DD);
        text = const Color(0xFF1A7A3A);
        break;
      case 'cancelled':
        bg = const Color(0xFFFFE0E0);
        text = const Color(0xFFD32F2F);
        break;
      default: // 'upcoming' or anything else
        bg = const Color(0xFFE3EEFF);
        text = const Color(0xFF1A55CC);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
