// Runs the demo engine for a simulated 14 hours and checks basic invariants.
// Usage:  dart run tool/sim_test.dart
import '../lib/engine/defs.dart';
import '../lib/engine/engine.dart';
import '../lib/engine/format.dart';

void check(bool ok, String msg) {
  if (!ok) {
    print('FAIL: $msg');
    throw StateError(msg);
  }
}

void main() {
  for (final start in [
    DateTime(2026, 10, 7, 7, 30),
    DateTime(2026, 10, 7, 13, 5),
    DateTime(2026, 10, 7, 23, 40),
    DateTime(2026, 10, 8, 3, 15),
  ]) {
    final e = DemoEngine(start: start, seed: 3);
    final p0 = e.partsTotal;
    check(p0 >= 0, 'seed parts');
    e.step(14 * 3600);
    check(e.partsTotal > 0, 'parts after run ($start)');
    for (final s in e.stations) {
      check(
        s.gun == null || (s.gun!.flow > 0 && s.gun!.flow < 20),
        'flow range ${s.def.id}',
      );
      check(
        s.gun == null || (s.gun!.temp > 10 && s.gun!.temp < 120),
        'temp range ${s.def.id} ${s.gun?.temp}',
      );
      check(s.downDay <= e.elapsedSec * 1.01 + 24 * 3600 * 2, 'downtime sane');
      for (final h in s.hourParts) {
        check(h >= 0, 'negative hour');
      }
    }
    final eff = e.efficiencyToday;
    print(
      'start ${hhmm(start)} -> now ${hhmm(e.now)} pos ${e.pos} shift ${shiftName(e.shift)} '
      'parts ${nf(e.partsTotal)} avail ${pct(e.availability, 1)} eff ${pct(eff, 0)} week ${pct(e.efficiencyWeek, 0)} '
      'alerts ${e.alerts.length} active ${e.activeAlerts.length} estops ${e.estops.length} down ${dur(e.downTotal())}',
    );
    // spot check on spot counts
    final s = e.byId('c1-op20');
    print(
      '  OP20 spots shift A ${nf(s.spots(0))} B ${nf(s.spots(1))} parts A ${s.parts(0)} B ${s.parts(1)} '
      '=> spots/part ${(s.spots(0) + s.spots(1)) / (s.partsDay == 0 ? 1 : s.partsDay)}',
    );
  }
  // manual fault injection
  final e = DemoEngine(start: DateTime(2026, 10, 7, 10, 0), seed: 5);
  e.autoFaults = false;
  e.step(60);
  e.raise('c2-op30', Fault.overheat, seconds: 120);
  e.raise('c1-op20', Fault.flowLow, seconds: 60);
  e.raise('c1-op10', Fault.estop, seconds: 80);
  e.step(50);
  check(
    e.byId('c2-op30').gun!.temp > 60,
    'overheat raised temp ${e.byId('c2-op30').gun!.temp}',
  );
  check(
    e.byId('c1-op20').gun!.flow < 10,
    'flow dropped ${e.byId('c1-op20').gun!.flow}',
  );
  check(e.byId('c1-op10').estopPressed, 'estop pressed');
  check(e.hmi['Cell 1']!.errorLatched, 'hmi error latched');
  print('active alerts during faults:');
  for (final a in e.activeAlerts) {
    print('  ${stationDef(a.stationId).title}: ${a.text} [${a.sev.name}]');
  }
  e.pressReset('Cell 1');
  check(
    e.hmi['Cell 1']!.errorLatched,
    'reset does not clear while fault still active',
  );
  e.step(200);
  e.pressReset('Cell 1');
  check(!e.hmi['Cell 1']!.errorLatched, 'reset clears after faults gone');
  check(e.estops.any((x) => x.endAt != null), 'estop closed');
  e.setMode('Cell 2', false);
  e.step(30);
  check(e.byId('c2-op20').blocked == 'manual', 'manual blocks');
  e.setMode('Cell 2', true);
  e.setWeld('Cell 2', false);
  e.step(5);
  check(e.byId('c2-op20').blocked == 'weld_off', 'weld off blocks');
  e.setWeld('Cell 2', true);
  // tip dressing happens
  final g = e.byId('c1-op30').gun!;
  g.sinceDress = g.dressFreq - 5;
  e.step(300);
  check(g.sinceDress < g.dressFreq, 'tip dressing happened');
  print('maintenance:');
  for (final m in e.maintenance()) {
    print(
      '  ${m.title}: ${nf(m.counted)} ${m.unit} ${m.used == null ? '' : pct(m.used, 2)}',
    );
  }
  print(
    'week: ${e.weekFor(null).map((d) => '${d.label} ${d.actual}/${d.plan}').join(', ')}',
  );
  print('ALL OK');
}
