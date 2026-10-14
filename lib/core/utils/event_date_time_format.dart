// Date and time formatting shared by every screen that shows events.
// Written by hand to avoid adding the `intl` package for two formats.
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// '15 Mar 2027'
String formatEventDate(DateTime d) =>
    '${d.day} ${_months[d.month - 1]} ${d.year}';

/// '10:00 AM'
String formatEventTime(DateTime d) {
  final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  final period = d.hour < 12 ? 'AM' : 'PM';
  return '$hour12:$minute $period';
}