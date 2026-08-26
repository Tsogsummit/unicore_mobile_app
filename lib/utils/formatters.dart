/// Returns up to the first two letters of the part before `@`, uppercased.
String initials(String value) {
  final base = value.split('@').first;
  if (base.length <= 2) return base.toUpperCase();
  return base.substring(0, 2).toUpperCase();
}

/// Formats a [DateTime] as `HH:mm:ss`.
String timeString(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
}

/// Formats a [DateTime] as a localized (Mongolian) weekday + date string.
String dateString(DateTime value) {
  const months = ['1-р сар', '2-р сар', '3-р сар', '4-р сар', '5-р сар', '6-р сар', '7-р сар', '8-р сар', '9-р сар', '10-р сар', '11-р сар', '12-р сар'];
  const weekdays = ['Даваа', 'Мягмар', 'Лхагва', 'Пүрэв', 'Баасан', 'Бямба', 'Ням'];
  return '${weekdays[value.weekday - 1]}, ${value.year} ${months[value.month - 1]} ${value.day}';
}
