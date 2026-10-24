import 'package:flutter/material.dart';

import '../app_state.dart';
import '../engine/defs.dart';
import '../engine/engine.dart';
import '../engine/format.dart';
import '../engine/stats.dart';
import '../ui/charts.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

String nuggetText(int n) {
  switch (n) {
    case 0:
      return 'Not due';
    case 1:
      return 'DUE';
    case 2:
      return 'Testing now';
    case 3:
      return 'Passed';
    default:
      return 'FAILED';
  }
}

Tone nuggetTone(int n) =>
    n == 4 ? Tone.bad : (n == 1 ? Tone.warn : (n == 2 ? Tone.sky : Tone.ok));

String flowText(FlowBand b) {
  switch (b) {
    case FlowBand.low:
      return 'TOO LOW';
    case FlowBand.poor:
      return 'POOR – not good';
    case FlowBand.good:
      return 'GOOD';
    case FlowBand.high:
      return 'HIGH – warning';
  }
}

Tone flowTone(FlowBand b) =>
    b == FlowBand.low ? Tone.bad : (b == FlowBand.good ? Tone.ok : Tone.warn);

String tempText(TempBand b) => b == TempBand.hot
    ? 'OVERHEATING'
    : (b == TempBand.warm ? 'Getting hot' : 'Normal');
Tone tempTone(TempBand b) =>
    b == TempBand.hot ? Tone.bad : (b == TempBand.warm ? Tone.warn : Tone.ok);

class WeldScreen extends StatelessWidget {
  const WeldScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final e = AppScope.of(context).engine;
    final w = WeldStats.of(e);
    final gs = e.guns;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        Grid(
          children: [
            Kpi(
              icon: Icons.water_drop,
              label: 'Water flow (avg)',
              value: w.avgFlow.toStringAsFixed(1),
              unit: 'LPM',
              tone: w.flowLow > 0
                  ? Tone.bad
                  : (w.flowPoor + w.flowHigh > 0 ? Tone.warn : Tone.ok),
              sub: 'Good range 10–13 LPM · poor below 10 · low below 7.5',
            ),
            Kpi(
              icon: Icons.thermostat,
              label: 'Hottest gun',
              value: w.hottest == null
                  ? '—'
                  : w.hottest!.gun!.temp.toStringAsFixed(0),
              unit: '°C',
              tone: w.hot > 0 ? Tone.bad : (w.warm > 0 ? Tone.warn : Tone.ok),
              sub: w.hottest?.def.title,
            ),
            Kpi(
              icon: Icons.electric_bolt,
              label: 'Weld current (avg)',
              value: w.avgKa.toStringAsFixed(1),
              unit: 'kA',
              tone: Tone.info,
              sub: '${w.avgV.toStringAsFixed(2)} V · last spot',
            ),
            Kpi(
              icon: Icons.flash_on,
              label: 'Spots today',
              value: nf(e.spotsTotal(0) + e.spotsTotal(1)),
              tone: Tone.teal,
              sub: 'A ${nf(e.spotsTotal(0))} · B ${nf(e.spotsTotal(1))}',
            ),
          ],
        ),
        const SectionTitle(
          'Weld guns',
          hint: 'One card per welding fixture',
          icon: Icons.bolt,
        ),
        for (final s in gs) ...[
          GunCard(s: s, e: e),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class GunCard extends StatelessWidget {
  final StationState s;
  final DemoEngine e;
  final bool showTitle;
  const GunCard({
    super.key,
    required this.s,
    required this.e,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final g = s.gun!;
    final fb = flowBand(g.flow);
    final tb = tempBand(g.temp);
    final dressPct = g.sinceDress / g.dressFreq;
    final changePct = g.sinceChange / g.tipLife;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showTitle)
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.def.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                Pill(statusText(s.status), tone: statusTone(s.status)),
              ],
            ),
          if (showTitle) const SizedBox(height: 10),
          // water flow
          Row(
            children: [
              const Icon(Icons.water_drop, size: 18, color: C.sky),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Water flow',
                  style: TextStyle(fontWeight: FontWeight.w700, color: C.muted),
                ),
              ),
              Text(
                '${g.flow.toStringAsFixed(1)} LPM',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
              const SizedBox(width: 8),
              Pill(flowText(fb), tone: flowTone(fb)),
            ],
          ),
          const SizedBox(height: 6),
          BandMeter(
            value: g.flow,
            min: 4,
            max: 16,
            zones: const [
              Slice(3.5, C.bad),
              Slice(2.5, C.warn),
              Slice(3, C.ok),
              Slice(3, C.warn),
            ],
          ),
          const Text(
            'Limits: 7.5 LPM = poor / not good · 13 LPM = good · above 13 = warning',
            style: TextStyle(fontSize: 11, color: C.muted),
          ),
          const SizedBox(height: 12),
          // temperature
          Row(
            children: [
              const Icon(Icons.thermostat, size: 18, color: C.warn),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Gun temperature',
                  style: TextStyle(fontWeight: FontWeight.w700, color: C.muted),
                ),
              ),
              Text(
                '${g.temp.toStringAsFixed(0)} °C',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
              const SizedBox(width: 8),
              Pill(tempText(tb), tone: tempTone(tb)),
            ],
          ),
          const SizedBox(height: 6),
          BandMeter(
            value: g.temp,
            min: 20,
            max: 100,
            zones: const [Slice(40, C.ok), Slice(20, C.warn), Slice(20, C.bad)],
          ),
          const SizedBox(height: 8),
          Spark(
            data: g.tempHist,
            color: C.warn,
            lo: 20,
            hi: 100,
            bandLo: 20,
            bandHi: 60,
            height: 44,
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          KV(
            'Weld current · voltage (last spot)',
            '${g.kA.toStringAsFixed(1)} kA · ${g.volt.toStringAsFixed(2)} V',
          ),
          KV(
            'Weld program',
            g.programOn ? 'ACTIVATED' : 'NOT activated',
            tone: g.programOn ? Tone.ok : Tone.bad,
          ),
          KV('Pulse', g.doublePulse ? 'Double pulse' : 'Single pulse'),
          KV(
            'Gun controller',
            g.ctrlOk ? 'Healthy' : 'UNHEALTHY',
            tone: g.ctrlOk ? Tone.ok : Tone.bad,
          ),
          KV(
            'Red Rabbit',
            g.redRabbit ? 'Active' : 'Inactive',
            tone: g.redRabbit ? Tone.teal : Tone.idle,
          ),
          KV('Spot counter (controller)', nf(g.spotCounter)),
          KV('Spots on this part', '${s.spotsInPart} of ${s.def.spots}'),
          const SizedBox(height: 6),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tip dressing',
                  style: TextStyle(fontSize: 13.5, color: C.muted),
                ),
              ),
              Text(
                g.dress == 2 ? 'Dressing now' : (g.dress == 1 ? 'DUE' : 'OK'),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: g.dress == 1 ? C.warn : C.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Bar(value: dressPct, tone: g.dress == 1 ? Tone.warn : Tone.info),
          Text(
            'Frequency set: every ${g.dressFreq} spots · ${g.sinceDress} since last dress',
            style: const TextStyle(fontSize: 11.5, color: C.muted),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tip change',
                  style: TextStyle(fontSize: 13.5, color: C.muted),
                ),
              ),
              Text(
                g.change == 2 ? 'Changing now' : (g.change == 1 ? 'DUE' : 'OK'),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: g.change == 1 ? C.warn : C.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Bar(value: changePct, tone: g.change == 1 ? Tone.warn : Tone.teal),
          Text(
            '${g.sinceChange} of ${g.tipLife} spots on this set of tips',
            style: const TextStyle(fontSize: 11.5, color: C.muted),
          ),
          const SizedBox(height: 6),
          KV('Nugget test', nuggetText(g.nugget), tone: nuggetTone(g.nugget)),
        ],
      ),
    );
  }
}
