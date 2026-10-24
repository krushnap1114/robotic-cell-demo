import 'package:flutter/material.dart';

import '../app_state.dart';
import '../engine/format.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class PlanningScreen extends StatefulWidget {
  const PlanningScreen({super.key});

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen> {
  String? _station; // null = all stations

  Tone _effTone(double? v) => v == null
      ? Tone.idle
      : (v >= 95 ? Tone.ok : (v >= 80 ? Tone.warn : Tone.bad));

  Future<void> _edit(BuildContext context, AppModel m, String id) async {
    final e = m.engine;
    final ctrl = TextEditingController(text: '${e.weeklyQty[id] ?? 0}');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Weekly plan – ${e.byId(id).def.title}'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Parts for the whole week',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(int.tryParse(ctrl.text.trim())),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null) {
      e.setWeekly(id, result);
      m.changed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = AppScope.of(context);
    final e = m.engine;
    final week = e.weekFor(_station);
    final totalPlan = week.fold(0, (a, d) => a + d.plan);
    final effWeek = e.efficiencyWeek;
    final effToday = e.efficiencyToday;
    final made = week.fold(
      0,
      (a, d) => a + ((d.state == 'done' || d.state == 'today') ? d.actual : 0),
    );
    var maxV = 1;
    for (final d in week) {
      if (d.plan > maxV) maxV = d.plan;
      if (d.actual > maxV) maxV = d.actual;
    }
    final today = week[e.dayIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly feeding plan'),
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
          Grid(
            children: [
              Kpi(
                icon: Icons.event_note,
                label: 'Weekly plan',
                value: nf(totalPlan),
                unit: 'parts',
                tone: Tone.info,
                sub: 'Spread over ${e.workDays.length} working days',
              ),
              Kpi(
                icon: Icons.check_circle,
                label: 'Made this week',
                value: nf(made),
                unit: 'parts',
                tone: Tone.teal,
                progress: totalPlan == 0 ? 0 : made / totalPlan,
              ),
              Kpi(
                icon: Icons.track_changes,
                label: 'Week efficiency',
                value: effWeek == null ? '—' : effWeek.toStringAsFixed(0),
                unit: effWeek == null ? null : '%',
                tone: _effTone(effWeek),
                sub: 'Actual vs plan so far',
              ),
              Kpi(
                icon: Icons.today,
                label: 'Today',
                value: nf(today.actual),
                unit: 'of ${nf(today.plan)}',
                tone: _effTone(effToday),
                sub: effToday == null
                    ? null
                    : 'Efficiency ${effToday.toStringAsFixed(0)}% (time-adjusted)',
              ),
            ],
          ),
          const SectionTitle(
            'Day by day',
            hint: 'Plan per day = weekly quantity ÷ working days',
            icon: Icons.calendar_month,
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All stations'),
                  selected: _station == null,
                  onSelected: (_) => setState(() => _station = null),
                ),
                for (final s in e.stations) ...[
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: Text(s.def.title),
                    selected: _station == s.def.id,
                    onSelected: (_) => setState(() => _station = s.def.id),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              children: [
                for (final d in week)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 42,
                              child: Text(
                                d.label,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: d.state == 'today' ? C.brand : C.ink,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                d.state == 'off'
                                    ? 'Not a working day'
                                    : '${nf(d.actual)} / ${nf(d.plan)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: d.state == 'future' || d.state == 'off'
                                      ? C.muted
                                      : C.ink,
                                ),
                              ),
                            ),
                            if (d.state == 'today')
                              const Pill('TODAY', tone: Tone.info),
                            if (d.eff != null) ...[
                              const SizedBox(width: 6),
                              Pill(
                                '${d.eff!.toStringAsFixed(0)}%',
                                tone: _effTone(d.eff),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Stack(
                          children: [
                            Bar(
                              value: d.plan / maxV,
                              tone: Tone.idle,
                              height: 9,
                            ),
                            if (d.state == 'done' || d.state == 'today')
                              Bar(
                                value: d.actual / maxV,
                                tone: d.state == 'today'
                                    ? Tone.info
                                    : Tone.teal,
                                height: 9,
                                bg: const Color(0x00000000),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          SectionTitle(
            'Plan per station',
            hint: 'Tap a row to change the weekly quantity',
            icon: Icons.table_chart,
            trailing: m.canControl
                ? PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'sample') {
                        e.loadSamplePlan();
                        m.changed();
                        demoSnack(context, 'Sample plan loaded');
                      } else {
                        demoSnack(
                          context,
                          'Demo: the full app reads an Excel / CSV file here',
                        );
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem<String>(
                        value: 'sample',
                        child: Text('Load sample plan'),
                      ),
                      PopupMenuItem<String>(
                        value: 'import',
                        child: Text('Import Excel / CSV (demo)'),
                      ),
                    ],
                  )
                : null,
          ),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              children: [
                Row(
                  children: const [
                    Expanded(
                      flex: 4,
                      child: Text(
                        'Station',
                        style: TextStyle(
                          fontSize: 12,
                          color: C.muted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Weekly',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          color: C.muted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Per day',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          color: C.muted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Per shift',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          color: C.muted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(),
                for (final s in e.stations)
                  InkWell(
                    onTap: m.canControl
                        ? () => _edit(context, m, s.def.id)
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Text(
                              s.def.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              nf(e.weeklyQty[s.def.id] ?? 0),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              nf(e.planToday(s.def.id)),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              nf(e.planShift(s.def.id)),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (!m.canControl)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Only Admin and Supervisor can edit the plan.',
                style: TextStyle(color: C.muted, fontSize: 12.5),
              ),
            ),
        ],
      ),
    );
  }
}
