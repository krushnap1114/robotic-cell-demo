// Small formatting helpers (pure Dart).

String nf(num n) {
  final neg = n < 0;
  final s = n.abs().round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '${neg ? '-' : ''}$b';
}

/// Seconds to "2 h 15 min" / "45 min" / "0 min".
String dur(int sec) {
  if (sec <= 0) return '0 min';
  final m = (sec / 60).round();
  if (m < 1) return '<1 min';
  final h = m ~/ 60;
  final r = m % 60;
  if (h == 0) return '$m min';
  return r == 0 ? '$h h' : '$h h $r min';
}

String pct(double? v, [int d = 0]) =>
    v == null ? '—' : '${v.toStringAsFixed(d)}%';

String two(int n) => n < 10 ? '0$n' : '$n';

String hhmm(DateTime t) => '${two(t.hour)}:${two(t.minute)}';
String hhmmss(DateTime t) => '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';

String ago(DateTime from, DateTime now) {
  final s = now.difference(from).inSeconds;
  if (s < 60) return '${s < 0 ? 0 : s} s ago';
  if (s < 3600) return '${s ~/ 60} min ago';
  return '${s ~/ 3600} h ${(s % 3600) ~/ 60} min ago';
}
