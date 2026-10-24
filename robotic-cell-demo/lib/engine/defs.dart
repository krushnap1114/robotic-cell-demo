// Static definitions: stations, reasons, faults, shift helpers.
// Pure Dart (no Flutter imports) so the engine can be tested with `dart run`.

class StationDef {
  final String id;
  final String cell;
  final String label;

  /// Weld spots per finished part (target given by the plant). 0 = no welding.
  final int spots;

  /// Typical cycle time in seconds.
  final int cycleSec;
  const StationDef(this.id, this.cell, this.label, this.spots, this.cycleSec);
  bool get welds => spots > 0;
  String get title => '$cell · $label';
}

const List<StationDef> kStations = [
  StationDef('c1-op10', 'Cell 1', 'OP 10', 3, 22),
  StationDef('c1-op20', 'Cell 1', 'OP 20', 52, 51),
  StationDef('c1-op30', 'Cell 1', 'OP 30', 66, 60),
  StationDef('c1-op80', 'Cell 1', 'OP 80', 36, 42),
  StationDef('c1-seal', 'Cell 1', 'Sealant Fixture', 0, 40),
  StationDef('c2-op10', 'Cell 2', 'OP 10', 28, 37),
  StationDef('c2-op20', 'Cell 2', 'OP 20', 29, 37),
  StationDef('c2-op30', 'Cell 2', 'OP 30', 31, 39),
  StationDef('c2-op50', 'Cell 2', 'OP 50', 2, 21),
  StationDef('c2-op60', 'Cell 2', 'OP 60', 18, 31),
  StationDef('c2-op70', 'Cell 2', 'OP 70', 71, 63),
];

const List<String> kCells = ['Cell 1', 'Cell 2'];

StationDef stationDef(String id) => kStations.firstWhere((s) => s.id == id);

class Reason {
  final String id;
  final String label;
  final String group;
  const Reason(this.id, this.label, this.group);
}

const List<Reason> kReasons = [
  Reason('estop', 'Emergency stop pressed', 'Safety'),
  Reason('door', 'Safety door open', 'Safety'),
  Reason('curtain', 'Light curtain blocked', 'Safety'),
  Reason('air', 'Low air pressure', 'Utilities'),
  Reason('water_pressure', 'Low water pressure', 'Utilities'),
  Reason('electro', 'Electropneumatic supply OFF', 'Utilities'),
  Reason('flow_low', 'Low water flow', 'Weld gun'),
  Reason('overheat', 'Gun overheated', 'Weld gun'),
  Reason('controller', 'Gun controller unhealthy', 'Weld gun'),
  Reason('nugget_fail', 'Nugget test failed', 'Weld gun'),
  Reason('clamp', 'Clamp fault / stuck', 'Machine'),
  Reason('mpcb', 'Motor protection tripped', 'Machine'),
  Reason('hold', 'Cycle hold', 'Operator / HMI'),
  Reason('cycle_stop', 'Cycle stop', 'Operator / HMI'),
  Reason('manual', 'HMI in manual mode', 'Operator / HMI'),
  Reason('weld_off', 'HMI weld switched OFF', 'Operator / HMI'),
  Reason('hmi_error', 'HMI error active', 'Operator / HMI'),
  Reason('tip_dress', 'Tip dressing', 'Planned'),
  Reason('tip_change', 'Tip change', 'Planned'),
  Reason('nugget_test', 'Nugget test', 'Planned'),
  Reason('idle', 'Waiting / no part', 'Waiting'),
];

Reason reasonOf(String id) => kReasons.firstWhere(
  (r) => r.id == id,
  orElse: () => Reason(id, id, 'Machine'),
);

const Map<String, int> kGroupColor = {
  'Safety': 0xFFDC2626,
  'Weld gun': 0xFFEA580C,
  'Utilities': 0xFF2563EB,
  'Machine': 0xFF7C3AED,
  'Operator / HMI': 0xFF0D9488,
  'Planned': 0xFFCA8A04,
  'Waiting': 0xFF64748B,
};

/// Faults that can be injected in the demo.
/// [stops]: the station stops. [derived]: the alert comes from the gun values, not from the fault itself.
enum Fault {
  estop('estop', 'Emergency stop pressed', false, true, false),
  door('door', 'Safety door open', false, true, false),
  curtain('curtain', 'Light curtain blocked', false, true, false),
  air('air', 'Low air pressure', false, true, false),
  waterPressure('water_pressure', 'Low water pressure', false, true, false),
  electro('electro', 'Electropneumatic supply OFF', false, true, false),
  clamp('clamp', 'Clamp fault / stuck', false, true, false),
  mpcb('mpcb', 'Motor protection tripped', false, true, false),
  flowLow('flow_low', 'Low water flow', true, true, true),
  overheat('overheat', 'Gun overheated', true, true, true),
  controller('controller', 'Gun controller unhealthy', true, true, true),
  nuggetFail('nugget_fail', 'Nugget test failed', true, true, true),
  flowHigh('', 'Water flow above limit', true, false, true);

  final String reason;
  final String label;
  final bool weldOnly;
  final bool stops;
  final bool derived;
  const Fault(this.reason, this.label, this.weldOnly, this.stops, this.derived);
}

// ---------------------------------------------------------------- shifts
// Production day starts 07:00. Position 0..23 = hours since 07:00.
// Shift A = 07:00-19:00 (positions 0-11), Shift B = 19:00-07:00 (positions 12-23).

DateTime dayStartOf(DateTime t) {
  var d = DateTime(t.year, t.month, t.day, 7);
  if (t.isBefore(d)) d = DateTime(t.year, t.month, t.day - 1, 7);
  return d;
}

int posOf(DateTime t) {
  final p = t.difference(dayStartOf(t)).inHours;
  return p < 0 ? 0 : (p > 23 ? 23 : p);
}

int shiftOfPos(int pos) => pos < 12 ? 0 : 1;
String shiftName(int i) => i == 0 ? 'A' : 'B';
String shiftRange(int i) => i == 0 ? '07:00 – 19:00' : '19:00 – 07:00';
int clockHour(int pos) => (7 + pos) % 24;

/// Limits (editable defaults in the real dashboard).
class Limits {
  final double flowMin = 7.5; // below = too low (alarm)
  final double flowPoor = 10; // up to here = poor, not good
  final double flowMax = 13; // above = warning
  final double tempWarn = 60;
  final double tempAlarm = 80;
  final int idleGraceSec = 120;
  const Limits();
}

const kLimits = Limits();

enum FlowBand { low, poor, good, high }

FlowBand flowBand(double lpm) {
  if (lpm < kLimits.flowMin) return FlowBand.low;
  if (lpm < kLimits.flowPoor) return FlowBand.poor;
  if (lpm <= kLimits.flowMax) return FlowBand.good;
  return FlowBand.high;
}

enum TempBand { ok, warm, hot }

TempBand tempBand(double c) {
  if (c >= kLimits.tempAlarm) return TempBand.hot;
  if (c >= kLimits.tempWarn) return TempBand.warm;
  return TempBand.ok;
}
