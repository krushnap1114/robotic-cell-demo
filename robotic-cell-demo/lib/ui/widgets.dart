import 'package:flutter/material.dart';

import '../engine/engine.dart';
import 'theme.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: C.line),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? hint;
  final IconData? icon;
  final Widget? trailing;
  const SectionTitle(
    this.title, {
    super.key,
    this.hint,
    this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null)
            Container(
              width: 34,
              height: 34,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: C.brandSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: C.brand),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: C.ink,
                  ),
                ),
                if (hint != null)
                  Text(
                    hint!,
                    style: const TextStyle(fontSize: 12.5, color: C.muted),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Tone tone;
  final IconData? icon;
  const Pill(this.text, {super.key, this.tone = Tone.idle, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: toneBg(tone),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: toneFg(tone)),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: toneFg(tone),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DemoBadge extends StatelessWidget {
  const DemoBadge({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: C.warnSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: C.warn),
      ),
      child: const Text(
        'DEMO DATA',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Color(0xFF6B3A05),
        ),
      ),
    );
  }
}

/// Lays children out in 2 columns on phones and 3-4 on tablets.
class Grid extends StatelessWidget {
  final List<Widget> children;
  final double gap;
  final int? columns;
  const Grid({super.key, required this.children, this.gap = 10, this.columns});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final cols = columns ?? (w >= 900 ? 4 : (w >= 600 ? 3 : 2));
        final cw = (w - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final ch in children) SizedBox(width: cw, child: ch)],
        );
      },
    );
  }
}

class Kpi extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final String? sub;
  final Tone tone;
  final double? progress;
  const Kpi({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
    this.sub,
    this.tone = Tone.info,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: toneBg(tone),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 18, color: toneFg(tone)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: C.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: tone == Tone.bad ? C.bad : C.ink,
                  ),
                ),
                if (unit != null) ...[
                  const SizedBox(width: 5),
                  Text(
                    unit!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: C.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 6),
            Bar(value: progress!, tone: tone),
          ],
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(
              sub!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: C.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class MiniTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final Tone tone;
  const MiniTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
    this.tone = Tone.ok,
  });

  @override
  Widget build(BuildContext context) {
    final bad = tone == Tone.bad || tone == Tone.warn;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: bad ? toneBg(tone) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: bad ? toneFg(tone) : C.line,
          width: bad ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: toneFg(tone)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: C.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: tone == Tone.bad ? C.bad : C.ink,
            ),
          ),
          if (sub != null)
            Text(
              sub!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: C.muted),
            ),
        ],
      ),
    );
  }
}

class Bar extends StatelessWidget {
  final double value; // 0..1 (or percent / 100)
  final Tone tone;
  final double height;
  final Color? bg;
  const Bar({
    super.key,
    required this.value,
    this.tone = Tone.info,
    this.height = 8,
    this.bg,
  });

  @override
  Widget build(BuildContext context) {
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0).toDouble();
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: v,
        minHeight: height,
        backgroundColor: bg ?? C.idleSoft,
        valueColor: AlwaysStoppedAnimation<Color>(toneFg(tone)),
      ),
    );
  }
}

class KV extends StatelessWidget {
  final String k;
  final String v;
  final Tone? tone;
  const KV(this.k, this.v, {super.key, this.tone});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              k,
              style: const TextStyle(fontSize: 13.5, color: C.muted),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              v,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: tone == null ? C.ink : toneFg(tone!),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Tone statusTone(Status s) {
  switch (s) {
    case Status.running:
      return Tone.ok;
    case Status.waiting:
      return Tone.info;
    case Status.stopped:
      return Tone.warn;
    case Status.planned:
      return Tone.sky;
    case Status.fault:
      return Tone.bad;
  }
}

String statusText(Status s) {
  switch (s) {
    case Status.running:
      return 'Running';
    case Status.waiting:
      return 'Waiting for part';
    case Status.stopped:
      return 'Stopped';
    case Status.planned:
      return 'Planned stop';
    case Status.fault:
      return 'FAULT';
  }
}

Tone sevTone(Sev s) =>
    s == Sev.bad ? Tone.bad : (s == Sev.warn ? Tone.warn : Tone.info);

void demoSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
  );
}
