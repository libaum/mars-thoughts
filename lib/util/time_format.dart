/// Compact, quiet relative time for the thought list: "now", "5m", "3h",
/// "2d", then an absolute short date for anything older than a week.
String formatThoughtTime(DateTime time, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final diff = reference.difference(time);

  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';

  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final monthName = months[time.month - 1];
  if (time.year == reference.year) return '$monthName ${time.day}';
  return '$monthName ${time.day}, ${time.year}';
}
