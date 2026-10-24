import 'package:flutter/material.dart';

import '../app_state.dart';
import '../engine/defs.dart';
import '../engine/engine.dart';
import '../engine/format.dart';
import '../ui/charts.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'weld.dart';

class StationsScreen extends StatelessWidget {
  const StationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final e = AppScope.of(context).engine;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        for (final cell in kCells) ...[
          SectionTitle(
            cell,
            hint:
                '${e.stations.where((s) => s.def.cell == cell).length} fixtures',
            icon: Icons.precision_manufacturing,
          ),
          for (final s in e.stations.where((s) => s.def.cell == cell)) ...[
            _StationCard(s: s, e: e),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}

class _StationCard extends StatelessWidget {
  final StationState s;
  final DemoEngine e;
  const _StationCard({required this.s, required this.e});

  @override
  Widget build(BuildContext context) {
    final sh = e.shift;
    final plan = e.planShift(s.def.id);
    final parts = s.parts(sh);
    final spotTarget = plan * s.def.spots;
    final spotDone = s.spots(sh);
    final g = s.gun;
    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => StationDetailScreen(id: s.def.id)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s.def.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ),
              Pill(statusText(s.status), tone: statusTone(s.status)),
              const Icon(Icons.chevron_right, color: C.muted),
            ],
          ),
          if (s.blocked != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Reason: ${reasonOf(s.blocked!).label}',
                style: const TextStyle(
                  color: C.bad,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  'Parts (shift ${shiftName(sh)})',
                  '${nf(parts)} / ${nf(plan)}',
                ),
              ),
              Expanded(child: _Stat('Cycle time', '${s.lastCycle} s')),
              Expanded(child: _Stat('Downtime', dur(s.downDay))),
            ],
          ),
          const SizedBox(height: 8),
          Bar(value: plan == 0 ? 0 : parts / plan, tone: Tone.info),
          if (s.def.welds) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Spots: ${nf(spotDone)} of ${nf(spotTarget)}  (${s.def.spots} per part)',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (g != null)
                  Text(
                    '${g.flow.toStringAsFixed(1)} LPM · ${g.temp.toStringAsFixed(0)} °C',
                    style: const TextStyle(fontSize: 12.5, color: C.muted),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Bar(
              value: spotTarget == 0 ? 0 : spotDone / spotTarget,
              tone: Tone.teal,
            ),
          ] else ...[
            const SizedBox(height: 8),
            const Text(
              'Sealant fixture – no weld spots',
              style: TextStyle(fontSize: 12.5, color: C.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String k;
  final String v;
  const _Stat(this.k, this.v);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          k,
          style: const TextStyle(
            fontSize: 11.5,
            color: C.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            v,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class StationDetailScreen extends StatelessWidget {
  final String id;
  const StationDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final m = AppScope.of(context);
    final e = m.engine;
    final s = e.byId(id);
    final downs = <String, int>{};
    for (var i = 0; i < 2; i++) {
      s.down[i].forEach((k, v) => downs[k] = (downs[k] ?? 0) + v);
    }
    final list = downs.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxD = list.isEmpty ? 1 : list.first.value;
    final myAlerts = e.activeAlerts.where((a) => a.stationId == id).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(s.def.title),
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
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        statusText(s.status),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: toneFg(statusTone(s.status)),
                        ),
                      ),
                    ),
                    Pill('Cycle ${s.lastCycle} s', tone: Tone.sky),
                  ],
                ),
                if (s.blocked != null)
                  Text(
                    'Reason: ${reasonOf(s.blocked!).label}',
                    style: const TextStyle(
                      color: C.bad,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const SizedBox(height: 8),
                Bar(
                  value: s.cycleLen == 0 ? 0 : s.cycleT / s.cycleLen,
                  tone: Tone.ok,
                ),
                Text(
                  'Current cycle ${s.cycleT.toStringAsFixed(0)} of ${s.cycleLen} s',
                  style: const TextStyle(fontSize: 12, color: C.muted),
                ),
              ],
            ),
          ),
          if (myAlerts.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final a in myAlerts)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: AppCard(
                  color: toneBg(sevTone(a.sev)),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: toneFg(sevTone(a.sev)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          a.text,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          const SectionTitle('Production', icon: Icons.inventory_2),
          AppCard(
            child: Column(
              children: [
                KV(
                  'Parts – Shift A',
                  '${nf(s.parts(0))} of ${nf(e.planShift(id))}',
                ),
                KV(
                  'Parts – Shift B',
                  '${nf(s.parts(1))} of ${nf(e.planShift(id))}',
                ),
                KV('Parts today', nf(s.partsDay)),
                KV('Today\'s plan', nf(e.planToday(id))),
                if (s.def.welds) ...[
                  const Divider(),
                  KV('Spots per part (target)', '${s.def.spots}'),
                  KV(
                    'Spots – Shift A',
                    '${nf(s.spots(0))} of ${nf(e.planShift(id) * s.def.spots)}',
                  ),
                  KV(
                    'Spots – Shift B',
                    '${nf(s.spots(1))} of ${nf(e.planShift(id) * s.def.spots)}',
                  ),
                ],
                const SizedBox(height: 6),
                HourlyChart(values: s.hourParts, nowPos: e.pos, height: 130),
              ],
            ),
          ),
          if (s.gun != null) ...[
            const SectionTitle('Weld gun', icon: Icons.bolt),
            GunCard(s: s, e: e, showTitle: false),
          ],
          const SectionTitle('Safety & air', icon: Icons.shield),
          AppCard(
            child: Column(
              children: [
                KV(
                  'Emergency stop',
                  s.estopPressed ? 'PRESSED' : 'Released',
                  tone: s.estopPressed ? Tone.bad : Tone.ok,
                ),
                KV('Presses today', '${s.estopToday}'),
                KV(
                  'Safety door',
                  s.doorClosed ? 'Closed' : 'OPEN',
                  tone: s.doorClosed ? Tone.ok : Tone.warn,
                ),
                KV(
                  'Electropneumatic',
                  s.electroOn ? 'ON' : 'OFF',
                  tone: s.electroOn ? Tone.ok : Tone.warn,
                ),
                KV(
                  'Air pressure',
                  s.airOk ? 'OK' : 'LOW',
                  tone: s.airOk ? Tone.ok : Tone.bad,
                ),
                KV(
                  'Water pressure',
                  s.waterOk ? 'OK' : 'LOW',
                  tone: s.waterOk ? Tone.ok : Tone.bad,
                ),
              ],
            ),
          ),
          SectionTitle(
            'Downtime by reason',
            hint: 'Shift A ${dur(s.downSec(0))} · Shift B ${dur(s.downSec(1))}',
            icon: Icons.hourglass_bottom,
          ),
          AppCard(
            child: Column(
              children: [
                for (final r in list.take(8))
                  _Row(id: r.key, sec: r.value, max: maxD),
                if (list.isEmpty) const Text('No downtime today.'),
              ],
            ),
          ),
          if (m.canControl) ...[
            const SectionTitle(
              'Demo controls',
              hint: 'Inject a problem to show how the app reacts',
              icon: Icons.science,
            ),
            AppCard(
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final f in Fault.values)
                    if (!f.weldOnly || s.gun != null)
                      ActionChip(
                        label: Text(f.label),
                        onPressed: () {
                          e.raise(id, f, seconds: 90);
                          m.changed();
                          demoSnack(
                            context,
                            'Demo: ${f.label} on ${s.def.title}',
                          );
                        },
                      ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String id;
  final int sec;
  final int max;
  const _Row({required this.id, required this.sec, required this.max});

  @override
  Widget build(BuildContext context) {
    final r = reasonOf(id);
    final color = Color(kGroupColor[r.group] ?? 0xFF64748B);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
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
              minHeight: 6,
              backgroundColor: C.idleSoft,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}
