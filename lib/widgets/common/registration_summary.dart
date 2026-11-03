import 'package:event_hive/core/theme/app_theme.dart';
import 'package:event_hive/core/utils/event_date_time_format.dart';
import 'package:event_hive/model/common/my_registration.dart';
import 'package:event_hive/widgets/common/event_thumbnail.dart';
import 'package:flutter/material.dart';

/// Small grey chip, for example 'Confirmed' or 'Paid'.
class StatusChip extends StatelessWidget {
  final String label;
  const StatusChip(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: kBorder,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: kTextMain,
        ),
      ),
    );
  }
}

/// White card with the event of a registration: thumbnail, title, an
/// optional status chip, and when and where it takes place.
class EventSummaryCard extends StatelessWidget {
  final MyRegistration reg;

  /// Text of the chip under the title, or null for no chip.
  final String? chip;

  const EventSummaryCard({super.key, required this.reg, this.chip});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EventThumbnail(imageUrl: reg.imageUrl, fallback: kNavy, size: 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reg.eventTitle,
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kTextMain,
                  ),
                ),
                if (chip != null) ...[
                  const SizedBox(height: 4),
                  StatusChip(chip!),
                ],
                const SizedBox(height: 4),
                Text(
                  '${formatEventDate(reg.eventStartsAt)} · '
                  '${formatEventTime(reg.eventStartsAt)} · ${reg.venue}',
                  style: const TextStyle(fontSize: 12, color: kTextSub),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// White card holding [rows], separated by thin lines.
class DetailsCard extends StatelessWidget {
  final List<DetailRow> rows;
  const DetailsCard({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i < rows.length - 1)
              const Divider(height: 1, color: kBorder),
          ],
        ],
      ),
    );
  }
}

/// One line of a [DetailsCard]: a label on the left and, on the right,
/// either text or a [StatusChip].
class DetailRow extends StatelessWidget {
  final String label;
  final String? value;
  final String? chip;

  const DetailRow({super.key, required this.label, this.value, this.chip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: kTextSub)),
          const SizedBox(width: 16),
          // Expanded lets a long list of add-ons wrap on the right.
          Expanded(
            child: chip != null
                ? Align(
                    alignment: Alignment.centerRight,
                    child: StatusChip(chip!),
                  )
                : Text(
                    value ?? '',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: kTextMain,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}