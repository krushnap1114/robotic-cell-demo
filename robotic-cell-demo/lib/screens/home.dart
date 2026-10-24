import 'package:flutter/material.dart';

import '../app_state.dart';
import '../engine/defs.dart';
import '../engine/engine.dart';
import '../engine/format.dart';
import '../engine/stats.dart';
import '../ui/charts.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'downtime.dart';
import 'planning.dart';
import 'safety.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final m = AppScope.of(context);
    final e = m.engine;
    final w = WeldStats.of(e);
    final sf = SafetyStats.of(e);
    final sh = e.shift;

    // spots for the running shift
    var spotDone = 0;
    var spotTarget = 0;
    for (final s in e.stations) {
      spotDone += s.spots(sh);
      spotTarget += e.planShift(s.def.id) * s.def.spots;
    }
    final spotsDay = e.spotsTotal(0) + e.spotsTotal(1);
    final eff = e.efficiencyToday;
    final effWeek = e.efficiencyWeek;
    final avail = e.availability;
    final active = e.activeAlerts;

    final hourly = List<int>.filled(24, 0);
    for (final s in e.stations) {
      for (var i = 0; i < 24; i++) {
        hourly[i] += s.hourParts[i];
      }
    }

    final flowTone = w.flowLow > 0
        ? Tone.bad
        : (w.flowPoor + w.flowHigh > 0 ? Tone.warn : Tone.ok);
    final tempTone = w.hot > 0 ? Tone.bad : (w.warm > 0 ? Tone.warn : Tone.ok);
    final reasons = e.downByReason(null).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topDown = reasons.take(5).toList();
    final maxDown = topDown.isEmpty ? 1 : topDown.first.value;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        // plant status
        AppCard(
          color: C.navy,
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: e.stoppedNow == 0 ? C.ok : C.warn,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  e.stoppedNow == 0 ? Icons.check : Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${e.runningNow} of ${e.stations.length} stations working',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      active.isEmpty
                          ? 'No active alerts · everything normal'
                          : '${active.length} active alert${active.length == 1 ? '' : 's'} · ${e.stoppedNow} station${e.stoppedNow == 1 ? '' : 's'} stopped',
                      style: const TextStyle(
                        color: Color(0xFFB9C6E6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SectionTitle(
          'Key numbers',
          hint: 'Today since 07:00',
          icon: Icons.speed,
        ),
        Grid(
          children: [
            Kpi(
              icon: Icons.inventory_2,
              label: 'Production count',
              value: nf(e.partsTotal),
              unit: 'parts',
              sub:
                  'Shift A ${nf(e.partsShiftTotal(0))} · Shift B ${nf(e.partsShiftTotal(1))}',
            ),
            Kpi(
              icon: Icons.flash_on,
              label: 'Spot count (shift ${shiftName(sh)})',
              value: nf(spotDone),
              unit: 'of ${nf(spotTarget)}',
              tone: Tone.teal,
              progress: spotTarget == 0 ? 0 : spotDone / spotTarget,
              sub: 'Today ${nf(spotsDay)} spots',
            ),
            Kpi(
              icon: Icons.timer,
              label: 'Cycle time (actual)',
              value: e.avgCycle.toStringAsFixed(0),
              unit: 'sec',
              tone: Tone.sky,
              sub: 'average of all stations',
            ),
            Kpi(
              icon: Icons.percent,
              label: 'Availability',
              value: avail.toStringAsFixed(1),
              unit: '%',
              tone: avail >= 90
                  ? Tone.ok
                  : (avail >= 75 ? Tone.warn : Tone.bad),
              progress: avail / 100,
              sub: '${e.stoppedNow} stopped now',
            ),
            Kpi(
              icon: Icons.hourglass_bottom,
              label: 'Downtime today',
              value: dur(e.downTotal()),
              tone: Tone.warn,
              sub: 'A ${dur(e.downTotal(0))} · B ${dur(e.downTotal(1))}',
            ),
            Kpi(
              icon: Icons.track_changes,
              label: 'Plan efficiency (today)',
              value: eff == null ? '—' : eff.toStringAsFixed(0),
              unit: eff == null ? null : '%',
              tone: eff == null
                  ? Tone.idle
                  : (eff >= 95 ? Tone.ok : (eff >= 80 ? Tone.warn : Tone.bad)),
              sub: effWeek == null
                  ? null
                  : 'Week so far ${effWeek.toStringAsFixed(0)}%',
            ),
            Kpi(
              icon: Icons.water_drop,
              label: 'Water flow (avg)',
              value: w.avgFlow.toStringAsFixed(1),
              unit: 'LPM',
              tone: flowTone,
              sub: w.flowLow + w.flowPoor + w.flowHigh == 0
                  ? 'All guns in range (7.5–13)'
                  : '${w.flowLow} low · ${w.flowPoor} poor · ${w.flowHigh} high',
            ),
            Kpi(
              icon: Icons.thermostat,
              label: 'Gun temperature (max)',
              value: w.hottest == null
                  ? '—'
                  : w.hottest!.gun!.temp.toStringAsFixed(0),
              unit: '°C',
              tone: tempTone,
              sub: w.hot > 0
                  ? '${w.hot} gun overheating'
                  : (w.warm > 0
                        ? '${w.warm} gun getting hot'
                        : 'No overheating'),
            ),
          ],
        ),

        SectionTitle(
          'Shift-wise production',
          hint: 'Two shifts: A 07:00–19:00 · B 19:00–07:00',
          icon: Icons.schedule,
        ),
        Grid(
          columns: 1,
          children: [
            _ShiftCard(e: e, shift: 0),
            _ShiftCard(e: e, shift: 1),
          ],
        ),
        const SizedBox(height: 10),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Parts made per hour',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const SizedBox(height: 6),
              HourlyChart(values: hourly, nowPos: e.pos),
            ],
          ),
        ),

        SectionTitle(
          'Weld guns',
          hint: 'Current, program, temperature, controller, tip care, nugget test',
          icon: Icons.bolt,
        ),
        Grid(
          children: [
            MiniTile(
              icon: Icons.electric_bolt,
              label: 'Weld current · voltage',
              value: '${w.avgKa.toStringAsFixed(1)} kA',
              sub: '${w.avgV.toStringAsFixed(2)} V · last spot',
              tone: Tone.info,
            ),
            MiniTile(
              icon: Icons.tune,
              label: 'Weld program',
              value: '${w.progOn} of ${w.guns} activated',
              sub: 'Single pulse ${w.single} · Double ${w.dbl}',
              tone: w.progOn == w.guns ? Tone.teal : Tone.warn,
            ),
            MiniTile(
              icon: Icons.thermostat,
              label: 'Gun temperature',
              value: w.hottest == null
                  ? '—'
                  : 'max ${w.hottest!.gun!.temp.toStringAsFixed(0)} °C',
              sub: w.hot > 0
                  ? '${w.hot} overheating'
                  : (w.warm > 0 ? '${w.warm} getting hot' : 'No overheating'),
              tone: tempTone,
            ),
            MiniTile(
              icon: Icons.monitor_heart,
              label: 'Gun controllers',
              value: w.ctrlOk == w.guns
                  ? 'All healthy'
                  : '${w.guns - w.ctrlOk} unhealthy',
              sub: '${w.ctrlOk} of ${w.guns} healthy',
              tone: w.ctrlOk == w.guns ? Tone.ok : Tone.bad,
            ),
            MiniTile(
              icon: Icons.build,
              label: 'Tip dressing',
              value: w.dressDue > 0 ? '${w.dressDue} due' : 'OK',
              sub: 'Frequency set per gun · ${w.dressing} dressing now',
              tone: w.dressDue > 0 ? Tone.warn : Tone.ok,
            ),
            MiniTile(
              icon: Icons.handyman,
              label: 'Tip change',
              value: w.changeDue > 0 ? '${w.changeDue} due' : 'OK',
              sub: '${w.changing} changing now',
              tone: w.changeDue > 0 ? Tone.warn : Tone.ok,
            ),
            MiniTile(
              icon: Icons.fact_check,
              label: 'Nugget test',
              value: w.nuggetFailed > 0
                  ? '${w.nuggetFailed} FAILED'
                  : (w.nuggetDue > 0 ? '${w.nuggetDue} due' : 'Passed'),
              sub: 'Passed ${w.nuggetPassed} · testing ${w.nuggetTesting}',
              tone: w.nuggetFailed > 0
                  ? Tone.bad
                  : (w.nuggetDue > 0 ? Tone.warn : Tone.ok),
            ),
            MiniTile(
              icon: Icons.local_fire_department,
              label: 'Red Rabbit',
              value: '${w.rabbitOn} active',
              sub: '${w.guns - w.rabbitOn} inactive',
              tone: Tone.teal,
            ),
          ],
        ),

        SectionTitle(
          'Safety & operator panels',
          hint: 'Emergency stops, doors, air supply, HMI',
          icon: Icons.shield,
          trailing: TextButton(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const SafetyScreen())),
            child: const Text('Open'),
          ),
        ),
        Grid(
          children: [
            MiniTile(
              icon: Icons.report,
              label: 'Emergency stops',
              value: sf.estopPressed > 0
                  ? '${sf.estopPressed} PRESSED'
                  : 'All released',
              sub: '${sf.estopToday} presses today',
              tone: sf.estopPressed > 0 ? Tone.bad : Tone.ok,
            ),
            MiniTile(
              icon: Icons.sensor_door,
              label: 'Safety doors',
              value: sf.doorsOpen > 0 ? '${sf.doorsOpen} OPEN' : 'All closed',
              sub: '${sf.stations - sf.doorsOpen} of ${sf.stations} closed',
              tone: sf.doorsOpen > 0 ? Tone.warn : Tone.ok,
            ),
            MiniTile(
              icon: Icons.air,
              label: 'Electropneumatic',
              value: '${sf.electroOn} of ${sf.stations} ON',
              sub: sf.electroOn < sf.stations
                  ? '${sf.stations - sf.electroOn} OFF'
                  : 'valve supply is ON',
              tone: sf.electroOn < sf.stations ? Tone.warn : Tone.sky,
            ),
            MiniTile(
              icon: Icons.pan_tool,
              label: 'HMI mode',
              value: kCells
                  .map((c) => e.hmi[c]!.auto ? 'AUTO' : 'MANUAL')
                  .join(' · '),
              sub: 'Cell 1 · Cell 2',
              tone: kCells.any((c) => !e.hmi[c]!.auto) ? Tone.warn : Tone.ok,
            ),
            MiniTile(
              icon: Icons.power_settings_new,
              label: 'HMI weld status',
              value: kCells
                  .map((c) => e.hmi[c]!.weldOn ? 'ON' : 'OFF')
                  .join(' · '),
              sub: 'Robot weld, Cell 1 · Cell 2',
              tone: kCells.any((c) => !e.hmi[c]!.weldOn) ? Tone.bad : Tone.ok,
            ),
            MiniTile(
              icon: Icons.play_circle,
              label: 'Cycle start · hold · stop',
              value: kCells
                  .map((c) => e.hmi[c]!.cycle.toUpperCase())
                  .join(' · '),
              sub: 'state of Cell 1 · Cell 2',
              tone: kCells.any((c) => e.hmi[c]!.cycle != 'start')
                  ? Tone.warn
                  : Tone.info,
            ),
            MiniTile(
              icon: Icons.error,
              label: 'HMI error',
              value: kCells.any((c) => e.hmi[c]!.errorActive)
                  ? 'ACTIVE'
                  : (kCells.any((c) => e.hmi[c]!.errorLatched)
                        ? 'Needs Reset'
                        : 'None'),
              sub: 'cleared when Reset is pressed',
              tone: kCells.any((c) => e.hmi[c]!.errorLatched)
                  ? Tone.bad
                  : Tone.ok,
            ),
            MiniTile(
              icon: Icons.flash_on,
              label: 'Spots per part (target)',
              value: '2–71',
              sub: 'OP10 = 3 … OP70 = 71',
              tone: Tone.idle,
            ),
          ],
        ),

        SectionTitle(
          'Downtime & weekly plan',
          hint: 'Top reasons today',
          icon: Icons.hourglass_bottom,
          trailing: TextButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const DowntimeScreen())),
            child: const Text('Open'),
          ),
        ),
        AppCard(
          child: Column(
            children: [
              for (final r in topDown)
                _ReasonRow(id: r.key, sec: r.value, max: maxDown),
              if (topDown.isEmpty) const Text('No downtime yet today.'),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PlanningScreen()),
                  ),
                  child: const Text('Open weekly plan →'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReasonRow extends StatelessWidget {
  final String id;
  final int sec;
  final int max;
  const _ReasonRow({required this.id, required this.sec, required this.max});

  @override
  Widget build(BuildContext context) {
    final r = reasonOf(id);
    final color = Color(kGroupColor[r.group] ?? 0xFF64748B);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
              Text(
                dur(sec),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: sec / max,
              minHeight: 7,
              backgroundColor: C.idleSoft,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  final DemoEngine e;
  final int shift;
  const _ShiftCard({required this.e, required this.shift});

  @override
  Widget build(BuildContext context) {
    final started = shift == 0 || e.shift == 1;
    final current = e.shift == shift;
    final parts = e.partsShiftTotal(shift);
    var plan = 0;
    var spots = 0;
    var spotPlan = 0;
    for (final s in e.stations) {
      plan += e.planShift(s.def.id);
      spots += s.spots(shift);
      spotPlan += e.planShift(s.def.id) * s.def.spots;
    }
    final color = shift == 0 ? C.brand : C.teal;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  shiftName(shift),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shift ${shiftName(shift)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      shiftRange(shift),
                      style: const TextStyle(color: C.muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Pill(
                current
                    ? 'RUNNING NOW'
                    : (started ? 'Finished' : 'Not started'),
                tone: current ? Tone.ok : Tone.idle,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _Num('Parts made', nf(parts), 'of ${nf(plan)}')),
              Expanded(child: _Num('Spots', nf(spots), 'of ${nf(spotPlan)}')),
              Expanded(child: _Num('Downtime', dur(e.downTotal(shift)), '')),
            ],
          ),
          const SizedBox(height: 8),
          Bar(
            value: plan == 0 ? 0 : parts / plan,
            tone: shift == 0 ? Tone.info : Tone.teal,
            height: 9,
          ),
          const SizedBox(height: 3),
          Text(
            plan == 0
                ? ''
                : '${(parts * 100 / plan).toStringAsFixed(0)}% of the shift plan',
            style: const TextStyle(fontSize: 12, color: C.muted),
          ),
        ],
      ),
    );
  }
}

class _Num extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  const _Num(this.label, this.value, this.sub);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: C.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
        ),
        if (sub.isNotEmpty)
          Text(sub, style: const TextStyle(fontSize: 11.5, color: C.muted)),
      ],
    );
  }
}
