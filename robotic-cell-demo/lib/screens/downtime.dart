import 'package:flutter/material.dart';

import '../app_state.dart';
import '../engine/defs.dart';
import '../engine/format.dart';
import '../ui/charts.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class DowntimeScreen extends StatefulWidget {
  const DowntimeScreen({super.key});

  @override
  State<DowntimeScreen> createState() => _DowntimeScreenState();
}

class _DowntimeScreenState extends State<DowntimeScreen> {
  int _sel = -1; // -1 whole day, 0 = A, 1 = B

  @override
  Widget build(BuildContext context) {
    final e = AppScope.of(context).engine;
    final int? sh = _sel < 0 ? null : _sel;
    final total = e.downTotal(sh);
    final byGroup = e.downByGroup(sh).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final byReason = e.downByReason(sh).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxR = byReason.isEmpty ? 1 : byReason.first.value;
    final stations = [...e.stations]
      ..sort(
        (a, b) => (sh == null ? b.downDay : b.downSec(sh)).compareTo(
          sh == null ? a.downDay : a.downSec(sh),
        ),
      );
    final int span = sh == null
        ? e.elapsedSec
        : (sh == 0
              ? (e.elapsedSec > 43200 ? 43200 : e.elapsedSec)
              : (e.elapsedSec > 43200 ? e.elapsedSec - 43200 : 1));
    final double availability = (100 - total * 100 / (span * e.stations.length))
        .clamp(0.0, 100.0)
        .toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downtime'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: DemoBadge()),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment<int>(value: -1, label: Text('Whole day')),
              ButtonSegment<int>(value: 0, label: Text('Shift A')),
              ButtonSegment<int>(value: 1, label: Text('Shift B')),
            ],
            selected: {_sel},
            onSelectionChanged: (s) => setState(() => _sel = s.first),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Row(
              children: [
                Donut(
                  size: 140,
                  center: dur(total),
                  sub: 'downtime',
                  slices: [
                    for (final g in byGroup)
                      Slice(
                        g.value.toDouble(),
                        Color(kGroupColor[g.key] ?? 0xFF64748B),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final g in byGroup)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Color(
                                    kGroupColor[g.key] ?? 0xFF64748B,
                                  ),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  g.key,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                dur(g.value),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (byGroup.isEmpty) const Text('No downtime.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Grid(
            children: [
              Kpi(
                icon: Icons.percent,
                label: 'Availability',
                value: availability.toStringAsFixed(1),
                unit: '%',
                tone: availability >= 90
                    ? Tone.ok
                    : (availability >= 75 ? Tone.warn : Tone.bad),
              ),
              Kpi(
                icon: Icons.hourglass_bottom,
                label: 'Total downtime',
                value: dur(total),
                tone: Tone.warn,
                sub: 'all 11 stations together',
              ),
            ],
          ),
          const SectionTitle(
            'By reason',
            hint: 'Hours and minutes, longest first',
            icon: Icons.list,
          ),
          AppCard(
            child: Column(
              children: [
                for (final r in byReason)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: Color(
                                  kGroupColor[reasonOf(r.key).group] ??
                                      0xFF64748B,
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                reasonOf(r.key).label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                            Text(
                              dur(r.value),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: r.value / maxR,
                            minHeight: 6,
                            backgroundColor: C.idleSoft,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(
                                kGroupColor[reasonOf(r.key).group] ??
                                    0xFF64748B,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (byReason.isEmpty) const Text('No downtime recorded.'),
              ],
            ),
          ),
          const SectionTitle('By station', icon: Icons.factory),
          AppCard(
            child: Column(
              children: [
                for (final s in stations)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.def.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          dur(sh == null ? s.downDay : s.downSec(sh)),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
