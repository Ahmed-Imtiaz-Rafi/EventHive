import 'package:event_hive/core/utils/event_date_time_format.dart';

/// '2 hours ago', '1 day ago', 'Just now'. Older than a month shows the
/// date instead.
String timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);

  String plural(int n, String unit) => '$n $unit${n == 1 ? '' : 's'} ago';

  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return plural(diff.inMinutes, 'minute');
  if (diff.inHours < 24) return plural(diff.inHours, 'hour');
  if (diff.inDays < 30) return plural(diff.inDays, 'day');
  return formatEventDate(time);
}