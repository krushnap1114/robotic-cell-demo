import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/defs.dart';
import 'theme.dart';

void _text(
  Canvas canvas,
  String s,
  Offset at, {
  double size = 10,
  Color color = C.muted,
  bool center = true,
  bool bold = false,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(
        fontSize: size,
        color: color,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  canvas.drawText(tp, at, center);
}

extension on Canvas {
  void drawText(TextPainter tp, Offset at, bool center) {
    tp.paint(this, center ? Offset(at.dx - tp.width / 2, at.dy) : at);
  }
}

/// 24 bars: parts made in every hour of the production day (07:00 to 07:00).
class HourlyChart extends StatelessWidget {
  final List<int> values;
  final int nowPos;
  final double height;
  const HourlyChart({
    super.key,
    required this.values,
    required this.nowPos,
    this.height = 150,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _HourlyPainter(values, nowPos)),
    );
  }
}

class _HourlyPainter extends CustomPainter {
  final List<int> v;
  final int nowPos;
  _HourlyPainter(this.v, this.nowPos);

  @override
  void paint(Canvas canvas, Size size) {
    const bottom = 18.0;
    const top = 14.0;
    final h = size.height - bottom - top;
    var maxV = 1;
    for (final x in v) {
      if (x > maxV) maxV = x;
    }
    final slot = size.width / 24;
    final bw = slot * 0.62;
    final grid = Paint()
      ..color = C.line
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, top + h), Offset(size.width, top + h), grid);
    canvas.drawLine(
      Offset(0, top),
      Offset(size.width, top),
      grid..color = C.line.withAlpha(120),
    );
    _text(canvas, '$maxV', const Offset(14, 0), size: 9.5, color: C.muted);
    for (var i = 0; i < 24; i++) {
      final x = i * slot + (slot - bw) / 2;
      final bh = v[i] / maxV * h;
      final isFuture = i > nowPos;
      final color = isFuture ? C.idleSoft : (i < 12 ? C.brand : C.teal);
      final r = RRect.fromRectAndCorners(
        Rect.fromLTWH(
          x,
          top + h - (isFuture ? 3 : math.max(bh, 2)),
          bw,
          isFuture ? 3 : math.max(bh, 2),
        ),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      );
      canvas.drawRRect(
        r,
        Paint()..color = i == nowPos ? color.withAlpha(150) : color,
      );
      if (i % 3 == 0) {
        _text(
          canvas,
          two(clockHour(i)),
          Offset(i * slot + slot / 2, top + h + 3),
          size: 9.5,
        );
      }
    }
    // shift divider
    final dx = slot * 12;
    canvas.drawLine(
      Offset(dx, top),
      Offset(dx, top + h),
      Paint()..color = C.line,
    );
    _text(
      canvas,
      'Shift A',
      Offset(slot * 6, 0),
      size: 10,
      bold: true,
      color: C.brand,
    );
    _text(
      canvas,
      'Shift B',
      Offset(slot * 18, 0),
      size: 10,
      bold: true,
      color: C.teal,
    );
  }

  String two(int n) => n < 10 ? '0$n' : '$n';

  @override
  bool shouldRepaint(covariant _HourlyPainter old) => true;
}

class Slice {
  final double value;
  final Color color;
  const Slice(this.value, this.color);
}

class Donut extends StatelessWidget {
  final List<Slice> slices;
  final String center;
  final String? sub;
  final double size;
  const Donut({
    super.key,
    required this.slices,
    required this.center,
    this.sub,
    this.size = 150,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: Size(size, size), painter: _DonutPainter(slices)),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: C.ink,
                ),
              ),
              if (sub != null)
                Text(
                  sub!,
                  style: const TextStyle(fontSize: 11, color: C.muted),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<Slice> slices;
  _DonutPainter(this.slices);

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold(0.0, (a, s) => a + s.value);
    final stroke = size.width * 0.16;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = C.idleSoft;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);
    if (total <= 0) return;
    var start = -math.pi / 2;
    for (final s in slices) {
      if (s.value <= 0) continue;
      final sweep = s.value / total * math.pi * 2;
      final gap = slices.length > 1 ? 0.03 : 0.0;
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = s.color;
      canvas.drawArc(
        rect,
        start + gap / 2,
        math.max(sweep - gap, 0.01),
        false,
        p,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => true;
}

/// Tiny line chart of the last readings, with an optional "good" band.
class Spark extends StatelessWidget {
  final List<double> data;
  final Color color;
  final double lo;
  final double hi;
  final double? bandLo;
  final double? bandHi;
  final double height;
  const Spark({
    super.key,
    required this.data,
    required this.color,
    required this.lo,
    required this.hi,
    this.bandLo,
    this.bandHi,
    this.height = 54,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparkPainter(data, color, lo, hi, bandLo, bandHi),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> d;
  final Color color;
  final double lo, hi;
  final double? bLo, bHi;
  _SparkPainter(this.d, this.color, this.lo, this.hi, this.bLo, this.bHi);

  double _y(double v, Size s) =>
      s.height - ((v - lo) / (hi - lo)).clamp(0.0, 1.0) * s.height;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
      Paint()..color = C.canvas,
    );
    if (bLo != null && bHi != null) {
      final r = Rect.fromLTRB(0, _y(bHi!, size), size.width, _y(bLo!, size));
      canvas.drawRect(r, Paint()..color = C.okSoft.withAlpha(170));
    }
    if (d.length < 2) return;
    final path = Path();
    for (var i = 0; i < d.length; i++) {
      final x = i / (d.length - 1) * size.width;
      final y = _y(d[i], size);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => true;
}

/// Horizontal band bar for water flow / temperature with coloured zones and a marker.
class BandMeter extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final List<Slice> zones; // widths in value units, coloured
  const BandMeter({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.zones,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      width: double.infinity,
      child: CustomPaint(painter: _BandPainter(value, min, max, zones)),
    );
  }
}

class _BandPainter extends CustomPainter {
  final double value, min, max;
  final List<Slice> zones;
  _BandPainter(this.value, this.min, this.max, this.zones);

  @override
  void paint(Canvas canvas, Size size) {
    final span = max - min;
    var x = 0.0;
    const barTop = 6.0;
    const barH = 8.0;
    for (final z in zones) {
      final w = z.value / span * size.width;
      canvas.drawRect(
        Rect.fromLTWH(x, barTop, w, barH),
        Paint()..color = z.color.withAlpha(200),
      );
      x += w;
    }
    final mx = ((value - min) / span).clamp(0.0, 1.0) * size.width;
    final path = Path()
      ..moveTo(mx, barTop + barH + 1)
      ..lineTo(mx - 5, barTop + barH + 8)
      ..lineTo(mx + 5, barTop + barH + 8)
      ..close();
    canvas.drawPath(path, Paint()..color = C.ink);
    canvas.drawRect(
      Rect.fromLTWH(mx - 1.5, 0, 3, barTop + barH),
      Paint()..color = C.ink,
    );
  }

  @override
  bool shouldRepaint(covariant _BandPainter old) => true;
}
