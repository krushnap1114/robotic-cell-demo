import 'package:flutter/material.dart';

import '../app_state.dart';
import '../engine/defs.dart';
import '../engine/engine.dart';
import '../engine/format.dart';
import '../engine/stats.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class SafetyScreen extends StatelessWidget {
  const SafetyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final m = AppScope.of(context);
    final e = m.engine;
    final sf = SafetyStats.of(e);
    final log = e.estops.reversed.take(12).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety & HMI'),
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
                icon: Icons.report,
                label: 'Emergency stops',
                value: sf.estopPressed > 0
                    ? '${sf.estopPressed} PRESSED'
                    : 'Released',
                tone: sf.estopPressed > 0 ? Tone.bad : Tone.ok,
                sub: '${sf.estopToday} presses today',
              ),
              Kpi(
                icon: Icons.sensor_door,
                label: 'Safety doors',
                value: sf.doorsOpen > 0 ? '${sf.doorsOpen} OPEN' : 'All closed',
                tone: sf.doorsOpen > 0 ? Tone.warn : Tone.ok,
                sub: '${sf.stations - sf.doorsOpen} of ${sf.stations} closed',
              ),
              Kpi(
                icon: Icons.air,
                label: 'Electropneumatic',
                value: '${sf.electroOn} of ${sf.stations}',
                unit: 'ON',
                tone: sf.electroOn < sf.stations ? Tone.warn : Tone.sky,
              ),
            ],
          ),
          const SectionTitle(
            'HMI panels',
            hint: 'Control panel of each cell – buttons work in the demo',
            icon: Icons.touch_app,
          ),
          for (final c in kCells) ...[
            _HmiCard(cell: c),
            const SizedBox(height: 10),
          ],
          const SectionTitle(
            'Emergency stop – every station',
            hint: 'State, presses today and last press',
            icon: Icons.report,
          ),
          AppCard(
            child: Column(
              children: [
                for (final s in e.stations)
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
                        Pill(
                          s.estopPressed ? 'PRESSED' : 'Released',
                          tone: s.estopPressed ? Tone.bad : Tone.ok,
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 52,
                          child: Text(
                            '${s.estopToday}×',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SectionTitle(
            'Emergency-stop log',
            hint: 'Time pressed and how long it stayed pressed',
            icon: Icons.history,
          ),
          AppCard(
            child: Column(
              children: [
                for (final ev in log) _EstopRow(ev: ev, now: e.now),
                if (log.isEmpty) const Text('No emergency stop pressed today.'),
              ],
            ),
          ),
          const SectionTitle('Safety doors', icon: Icons.sensor_door),
          AppCard(
            child: Column(
              children: [
                for (final s in e.stations)
                  KV(
                    s.def.title,
                    s.doorClosed ? 'Closed' : 'OPEN',
                    tone: s.doorClosed ? Tone.ok : Tone.warn,
                  ),
              ],
            ),
          ),
          if (m.canControl) ...[
            const SectionTitle('Demo controls', icon: Icons.science),
            AppCard(
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.report, size: 18),
                    label: const Text('Press E-stop (Cell 1 · OP 20)'),
                    onPressed: () {
                      e.raise('c1-op20', Fault.estop, seconds: 60);
                      m.changed();
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.sensor_door, size: 18),
                    label: const Text('Open door (Cell 2 · OP 30)'),
                    onPressed: () {
                      e.raise('c2-op30', Fault.door, seconds: 60);
                      m.changed();
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.clear_all, size: 18),
                    label: const Text('Clear all problems'),
                    onPressed: () {
                      e.clearAllFaults();
                      m.changed();
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

class _EstopRow extends StatelessWidget {
  final EstopEvent ev;
  final DateTime now;
  const _EstopRow({required this.ev, required this.now});

  @override
  Widget build(BuildContext context) {
    final held = (ev.endAt ?? now).difference(ev.at).inSeconds;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            Icons.report,
            size: 18,
            color: ev.endAt == null ? C.bad : C.muted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stationDef(ev.stationId).title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  'Pressed ${hhmmss(ev.at)}${ev.endAt == null ? ' · still pressed' : ' · released ${hhmmss(ev.endAt!)}'}',
                  style: const TextStyle(fontSize: 12, color: C.muted),
                ),
              ],
            ),
          ),
          Text(
            held < 60 ? '$held s' : dur(held),
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: ev.endAt == null ? C.bad : C.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _HmiCard extends StatelessWidget {
  final String cell;
  const _HmiCard({required this.cell});

  @override
  Widget build(BuildContext context) {
    final m = AppScope.of(context);
    final e = m.engine;
    final h = e.hmi[cell]!;
    final can = m.canControl;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$cell · HMI',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              Pill(
                h.errorActive
                    ? 'ERROR ACTIVE'
                    : (h.errorLatched ? 'Needs Reset' : 'No error'),
                tone: h.errorActive
                    ? Tone.bad
                    : (h.errorLatched ? Tone.warn : Tone.ok),
                icon: h.errorLatched ? Icons.error : Icons.check_circle,
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Mode',
            style: TextStyle(
              fontSize: 12.5,
              color: C.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(value: true, label: Text('AUTO')),
              ButtonSegment<bool>(value: false, label: Text('MANUAL')),
            ],
            selected: {h.auto},
            onSelectionChanged: can
                ? (s) {
                    e.setMode(cell, s.first);
                    m.changed();
                  }
                : null,
          ),
          const SizedBox(height: 10),
          const Text(
            'Robot weld',
            style: TextStyle(
              fontSize: 12.5,
              color: C.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(value: true, label: Text('WELD ON')),
              ButtonSegment<bool>(value: false, label: Text('WELD OFF')),
            ],
            selected: {h.weldOn},
            onSelectionChanged: can
                ? (s) {
                    e.setWeld(cell, s.first);
                    m.changed();
                  }
                : null,
          ),
          const SizedBox(height: 10),
          const Text(
            'Cycle',
            style: TextStyle(
              fontSize: 12.5,
              color: C.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(value: 'start', label: Text('START')),
              ButtonSegment<String>(value: 'hold', label: Text('HOLD')),
              ButtonSegment<String>(value: 'stop', label: Text('STOP')),
            ],
            selected: {h.cycle},
            onSelectionChanged: can
                ? (s) {
                    e.setCycle(cell, s.first);
                    m.changed();
                  }
                : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Reset pressed ${h.resets}× today',
                  style: const TextStyle(color: C.muted, fontSize: 12.5),
                ),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: h.errorLatched ? C.bad : C.idle,
                ),
                onPressed: can
                    ? () {
                        e.pressReset(cell);
                        m.changed();
                        demoSnack(
                          context,
                          h.errorActive
                              ? 'Reset pressed – a fault is still active'
                              : 'Reset pressed – HMI error cleared',
                        );
                      }
                    : null,
                icon: const Icon(Icons.restart_alt),
                label: const Text('RESET'),
              ),
            ],
          ),
          if (!can)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Operators can view only. Sign in as Admin or Supervisor to use the buttons.',
                style: TextStyle(fontSize: 12, color: C.muted),
              ),
            ),
        ],
      ),
    );
  }
}
