// Demo engine: simulates two robotic weld cells. ALL DATA IS DEMO DATA.
// Pure Dart (no Flutter imports).

import 'dart:math';

import 'defs.dart';

enum Status { running, waiting, stopped, planned, fault }

enum Sev { info, warn, bad }

class Gun {
  double flow = 11.6; // litres per minute
  double temp = 42; // °C
  double kA = 9.0; // weld current, last spot
  double volt = 2.1; // weld voltage, last spot
  bool ctrlOk = true;
  bool programOn = true;
  bool doublePulse = false;
  bool redRabbit = true;
  int dressFreq = 300; // dress the tips every N spots
  int sinceDress = 0;
  int dress = 0; // 0 ok, 1 due, 2 dressing now
  int tipLife = 3000; // change the tips every N spots
  int sinceChange = 0;
  int change = 0; // 0 ok, 1 due, 2 changing now
  int nuggetEvery = 4000;
  int sinceNugget = 0;
  int nugget = 3; // 0 not due, 1 due, 2 testing, 3 passed, 4 failed
  int spotCounter = 0; // spot counter of the controller
  final List<double> flowHist = [];
  final List<double> tempHist = [];
}

class StationState {
  final StationDef def;
  Gun? gun;
  Status status = Status.running;
  String? blocked; // reason id while the station is stopped
  Fault? fault;
  int faultLeft = 0;
  int cycleLen;
  double cycleT = 0;
  int lastCycle;
  int idleLeft = 0;
  int idleElapsed = 0;
  String? plannedReason;
  int plannedLeft = 0;
  double spotAcc = 0;
  int spotsInPart = 0; // spots done on the part being welded now
  final List<int> hourParts = List<int>.filled(24, 0);
  final List<int> hourSpots = List<int>.filled(24, 0);
  final List<Map<String, int>> down = [
    <String, int>{},
    <String, int>{},
  ]; // seconds, per shift
  bool doorClosed = true;
  bool electroOn = true;
  bool airOk = true;
  bool waterOk = true;
  bool estopPressed = false;
  int estopToday = 0;
  int lifeParts = 0; // parts before today (for the maintenance page)
  int lifeEstop = 0;
  int lifeMpcb = 0;

  StationState(this.def) : cycleLen = def.cycleSec, lastCycle = def.cycleSec;

  int parts(int shift) {
    var n = 0;
    for (var p = shift * 12; p < shift * 12 + 12; p++) {
      n += hourParts[p];
    }
    return n;
  }

  int get partsDay => parts(0) + parts(1);

  int spots(int shift) {
    var n = 0;
    for (var p = shift * 12; p < shift * 12 + 12; p++) {
      n += hourSpots[p];
    }
    return n;
  }

  int downSec(int shift) => down[shift].values.fold(0, (a, b) => a + b);
  int get downDay => downSec(0) + downSec(1);
}

class CellHmi {
  bool auto = true;
  bool weldOn = true;
  String cycle = 'start'; // start | hold | stop
  bool errorActive = false;
  bool errorLatched = false;
  int resets = 0;
  int quiet = 0;
}

class AlertItem {
  final int id;
  final String stationId;
  final String text;
  final Sev sev;
  final DateTime at;
  DateTime? endedAt;
  AlertItem(this.id, this.stationId, this.text, this.sev, this.at);
  bool get active => endedAt == null;
}

class EstopEvent {
  final String stationId;
  final DateTime at;
  DateTime? endAt;
  EstopEvent(this.stationId, this.at, [this.endAt]);
}

class _Cond {
  final String key;
  final String text;
  final Sev sev;
  const _Cond(this.key, this.text, this.sev);
}

class DayPlan {
  final String label;
  final int plan;
  final int actual;
  final String state; // done | today | future | off
  const DayPlan(this.label, this.plan, this.actual, this.state);
  double? get eff => plan > 0 && state != 'future' ? actual * 100 / plan : null;
}

class MaintItem {
  final String title;
  final String model;
  final double? rated;
  final double counted;
  final String unit;
  final String note;
  final String source;
  const MaintItem(
    this.title,
    this.model,
    this.rated,
    this.counted,
    this.unit,
    this.note,
    this.source,
  );
  double? get used => rated == null ? null : counted * 100 / rated!;
}

class DemoEngine {
  DemoEngine({DateTime? start, int seed = 7})
    : _rnd = Random(seed),
      now = start ?? DateTime.now() {
    _build();
  }

  DateTime now;
  final Random _rnd;
  final List<StationState> stations = [];
  final Map<String, CellHmi> hmi = {for (final c in kCells) c: CellHmi()};
  final List<AlertItem> alerts = [];
  final List<EstopEvent> estops = [];
  final Map<String, AlertItem> _open = {};
  final List<int> workDays = [
    1,
    2,
    3,
    4,
    5,
    6,
    7,
  ]; // Monday = 1 (demo: every day is a working day)
  Map<String, int> weeklyQty = {};
  final Map<String, List<int>> weekActual =
      {}; // finished days of this week (index 0 = Monday)
  bool autoFaults = true;
  bool planLoaded = true;
  int _alertId = 0;
  late DateTime _dayStart;

  StationState byId(String id) => stations.firstWhere((s) => s.def.id == id);
  List<StationState> get guns => stations.where((s) => s.gun != null).toList();
  int get pos => posOf(now);
  int get shift => shiftOfPos(pos);
  int get dayIndex => _dayStart.weekday - 1; // 0 = Monday

  // ------------------------------------------------------------- build / seed
  void _build() {
    _dayStart = dayStartOf(now);
    final pos = posOf(now);
    final inHour = (now.minute * 60 + now.second) / 3600.0;
    for (final d in kStations) {
      final s = StationState(d);
      if (d.welds) {
        final g = Gun();
        g.redRabbit = _rnd.nextInt(5) != 0;
        g.doublePulse = _rnd.nextInt(3) == 0;
        g.dressFreq = [250, 300, 300, 400][_rnd.nextInt(4)];
        g.tipLife = g.dressFreq * 10;
        g.sinceDress = _rnd.nextInt(g.dressFreq - 40);
        g.sinceChange = _rnd.nextInt(g.tipLife ~/ 2);
        g.sinceNugget = _rnd.nextInt(g.nuggetEvery ~/ 2);
        g.spotCounter = 120000 + _rnd.nextInt(380000);
        s.gun = g;
      }
      // production so far today
      final avail = 0.80 + _rnd.nextDouble() * 0.13;
      for (var p = 0; p <= pos; p++) {
        final frac = p < pos ? 1.0 : inHour;
        final n =
            (3600 / d.cycleSec * frac * avail * (0.9 + _rnd.nextDouble() * 0.2))
                .round();
        s.hourParts[p] = n;
        s.hourSpots[p] = n * d.spots;
      }
      s.lifeParts = 150000 + _rnd.nextInt(120000);
      s.lifeEstop = 1200 + _rnd.nextInt(5200);
      s.lifeMpcb = 2500 + _rnd.nextInt(6000);
      _seedDowntime(s, pos, inHour);
      stations.add(s);
    }
    // earlier e-stop presses today
    final elapsed = now.difference(_dayStart).inSeconds;
    if (elapsed > 3600) {
      for (var i = 0; i < 3; i++) {
        final st = stations[_rnd.nextInt(stations.length)];
        final at = _dayStart.add(
          Duration(
            seconds:
                600 + _rnd.nextInt(elapsed - 1200 < 60 ? 60 : elapsed - 1200),
          ),
        );
        estops.add(
          EstopEvent(
            st.def.id,
            at,
            at.add(Duration(seconds: 25 + _rnd.nextInt(90))),
          ),
        );
        st.estopToday++;
        st.lifeEstop++;
      }
      estops.sort((a, b) => a.at.compareTo(b.at));
    }
    // sample plan + earlier days of this week
    weeklyQty = samplePlan();
    for (final s in stations) {
      final list = List<int>.filled(7, 0);
      for (var i = 0; i < dayIndex; i++) {
        if (workDays.contains(i + 1)) {
          final daily = _planDay(s.def.id, i);
          list[i] = (daily * (0.84 + _rnd.nextDouble() * 0.2)).round();
        }
      }
      weekActual[s.def.id] = list;
    }
    _updateAlerts();
  }

  void _seedDowntime(StationState s, int pos, double inHour) {
    for (var sh = 0; sh < 2; sh++) {
      final startedHours = sh == 0
          ? (pos < 12 ? pos + inHour : 12.0)
          : (pos < 12 ? 0.0 : pos - 12 + inHour);
      if (startedHours <= 0) continue;
      final events = 1 + _rnd.nextInt(3);
      for (var i = 0; i < events; i++) {
        final r = _seedReason(s);
        final sec = (60 + _rnd.nextInt(660) * (startedHours / 12 + 0.2))
            .round();
        s.down[sh][r] = (s.down[sh][r] ?? 0) + sec;
      }
    }
  }

  String _seedReason(StationState s) {
    const common = [
      'hold',
      'idle',
      'manual',
      'tip_dress',
      'clamp',
      'air',
      'door',
      'cycle_stop',
      'hmi_error',
    ];
    const weld = [
      'flow_low',
      'overheat',
      'controller',
      'tip_change',
      'nugget_test',
      'nugget_fail',
      'weld_off',
    ];
    final pool = <String>[...common, if (s.def.welds) ...weld];
    return pool[_rnd.nextInt(pool.length)];
  }

  // ----------------------------------------------------------------- plan
  Map<String, int> samplePlan() {
    final m = <String, int>{};
    for (final d in kStations) {
      final daily = 86400 / d.cycleSec * 0.86;
      m[d.id] = ((daily * workDays.length) / 10).round() * 10;
    }
    return m;
  }

  int _planDay(String id, int dayIdx) {
    if (!workDays.contains(dayIdx + 1)) return 0;
    final w = weeklyQty[id] ?? 0;
    return (w / workDays.length).round();
  }

  int planToday(String id) => _planDay(id, dayIndex);
  int planShift(String id) => (planToday(id) / 2).round();
  int get planTodayTotal => stations.fold(0, (a, s) => a + planToday(s.def.id));
  int get weeklyTotal => weeklyQty.values.fold(0, (a, b) => a + b);

  List<DayPlan> weekFor(String? id) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final list = <DayPlan>[];
    for (var i = 0; i < 7; i++) {
      var plan = 0;
      var act = 0;
      for (final s in stations) {
        if (id != null && s.def.id != id) continue;
        plan += _planDay(s.def.id, i);
        if (i < dayIndex) act += weekActual[s.def.id]![i];
        if (i == dayIndex) act += s.partsDay;
      }
      final state = !workDays.contains(i + 1)
          ? 'off'
          : (i < dayIndex ? 'done' : (i == dayIndex ? 'today' : 'future'));
      list.add(DayPlan(names[i], plan, act, state));
    }
    return list;
  }

  void setWeekly(String id, int qty) => weeklyQty[id] = qty < 0 ? 0 : qty;
  void loadSamplePlan() {
    weeklyQty = samplePlan();
    planLoaded = true;
  }

  // -------------------------------------------------------------- numbers
  int get elapsedSec => max(1, now.difference(_dayStart).inSeconds);
  int get partsTotal => stations.fold(0, (a, s) => a + s.partsDay);
  int partsShiftTotal(int sh) => stations.fold(0, (a, s) => a + s.parts(sh));
  int spotsTotal(int sh) => stations.fold(0, (a, s) => a + s.spots(sh));
  int downTotal([int? sh]) =>
      stations.fold(0, (a, s) => a + (sh == null ? s.downDay : s.downSec(sh)));
  int get runningNow => stations
      .where((s) => s.status == Status.running || s.status == Status.waiting)
      .length;
  int get stoppedNow => stations.length - runningNow;

  double get availability {
    final total = elapsedSec * stations.length;
    return (100 - downTotal() * 100 / total).clamp(0, 100).toDouble();
  }

  double get avgCycle =>
      stations.fold(0.0, (a, s) => a + s.lastCycle) / stations.length;

  /// Efficiency of today: actual parts against the plan for the time gone so far.
  double? get efficiencyToday {
    final plan = planTodayTotal * (elapsedSec / 86400);
    if (plan <= 0) return null;
    return partsTotal * 100 / plan;
  }

  double? get efficiencyWeek {
    var plan = 0.0;
    var act = 0;
    final wk = weekFor(null);
    for (var i = 0; i < 7; i++) {
      if (wk[i].state == 'done') {
        plan += wk[i].plan;
        act += wk[i].actual;
      } else if (wk[i].state == 'today') {
        plan += wk[i].plan * (elapsedSec / 86400);
        act += wk[i].actual;
      }
    }
    if (plan <= 0) return null;
    return act * 100 / plan;
  }

  int get weekActualTotal => weekFor(null).fold(
    0,
    (a, d) => a + (d.state == 'future' || d.state == 'off' ? 0 : d.actual),
  );

  Map<String, int> downByReason(int? sh) {
    final m = <String, int>{};
    for (final s in stations) {
      for (var i = 0; i < 2; i++) {
        if (sh != null && sh != i) continue;
        s.down[i].forEach((k, v) => m[k] = (m[k] ?? 0) + v);
      }
    }
    return m;
  }

  Map<String, int> downByGroup(int? sh) {
    final m = <String, int>{};
    downByReason(sh).forEach((k, v) {
      final g = reasonOf(k).group;
      m[g] = (m[g] ?? 0) + v;
    });
    return m;
  }

  // ------------------------------------------------------------- weld stats
  double? get avgFlow {
    final g = guns;
    return g.isEmpty ? null : g.fold(0.0, (a, s) => a + s.gun!.flow) / g.length;
  }

  StationState? get hottest {
    final g = guns;
    if (g.isEmpty) return null;
    g.sort((a, b) => b.gun!.temp.compareTo(a.gun!.temp));
    return g.first;
  }

  // ------------------------------------------------------------ demo actions
  void raise(String stationId, Fault f, {int? seconds}) {
    final s = byId(stationId);
    if (s.fault != null) return;
    if (f.weldOnly && s.gun == null) return;
    s.fault = f;
    s.faultLeft = seconds ?? (45 + _rnd.nextInt(75));
    if (f == Fault.estop) {
      s.estopToday++;
      s.lifeEstop++;
      estops.add(EstopEvent(s.def.id, now));
    }
    if (f == Fault.nuggetFail && s.gun != null) s.gun!.nugget = 4;
    if (f.stops) {
      final h = hmi[s.def.cell]!;
      h.errorActive = true;
      h.errorLatched = true;
      h.quiet = 0;
    }
  }

  void _clear(StationState s) {
    final f = s.fault;
    if (f == null) return;
    if (f == Fault.estop) {
      for (var i = estops.length - 1; i >= 0; i--) {
        if (estops[i].stationId == s.def.id && estops[i].endAt == null) {
          estops[i].endAt = now;
          break;
        }
      }
    }
    if (f == Fault.nuggetFail && s.gun != null) {
      s.gun!.nugget = 3;
      s.gun!.sinceNugget = 0;
    }
    s.fault = null;
    s.faultLeft = 0;
  }

  void clearAllFaults() {
    for (final s in stations) {
      _clear(s);
    }
  }

  void pressReset(String cell) {
    final h = hmi[cell]!;
    h.resets++;
    if (!stations.any(
      (s) => s.def.cell == cell && s.fault != null && s.fault!.stops,
    )) {
      h.errorLatched = false;
      h.errorActive = false;
    }
  }

  void setMode(String cell, bool auto) => hmi[cell]!.auto = auto;
  void setWeld(String cell, bool on) => hmi[cell]!.weldOn = on;
  void setCycle(String cell, String c) => hmi[cell]!.cycle = c;

  // ------------------------------------------------------------------ step
  void step([int seconds = 1]) {
    for (var i = 0; i < seconds; i++) {
      _step1();
    }
  }

  void _rollDay() {
    for (final s in stations) {
      final idx = _dayStart.weekday - 1;
      weekActual[s.def.id]![idx] = s.partsDay;
      s.lifeParts += s.partsDay;
      for (var p = 0; p < 24; p++) {
        s.hourParts[p] = 0;
        s.hourSpots[p] = 0;
      }
      s.down[0].clear();
      s.down[1].clear();
      s.estopToday = 0;
    }
    estops.clear();
    _dayStart = dayStartOf(now);
    if (_dayStart.weekday == 1) {
      for (final s in stations) {
        weekActual[s.def.id] = List<int>.filled(7, 0);
      }
    }
  }

  void _step1() {
    now = now.add(const Duration(seconds: 1));
    if (dayStartOf(now) != _dayStart) _rollDay();
    final p = posOf(now);
    final sh = shiftOfPos(p);

    for (final s in stations) {
      final h = hmi[s.def.cell]!;
      // faults
      if (s.fault != null) {
        s.faultLeft--;
        if (s.faultLeft <= 0) _clear(s);
      } else if (autoFaults && _rnd.nextInt(3200) == 0) {
        raise(s.def.id, _pickFault(s));
      }
      final f = s.fault;
      s.estopPressed = f == Fault.estop;
      s.doorClosed = f != Fault.door;
      s.electroOn = f != Fault.electro;
      s.airOk = f != Fault.air;
      s.waterOk = f != Fault.waterPressure;

      // why is the station not working?
      String? why;
      if (f != null && f.stops) {
        why = f.reason;
      } else if (!h.auto) {
        why = 'manual';
      } else if (h.cycle == 'stop') {
        why = 'cycle_stop';
      } else if (h.cycle == 'hold') {
        why = 'hold';
      } else if (s.def.welds && !h.weldOn) {
        why = 'weld_off';
      } else if (s.plannedLeft > 0) {
        why = s.plannedReason;
        s.plannedLeft--;
        if (s.plannedLeft == 0) _finishPlanned(s);
      }
      s.blocked = why;

      var welding = false;
      if (why != null) {
        if (f != null && f.stops) {
          s.status = Status.fault;
        } else if (why == 'tip_dress' ||
            why == 'tip_change' ||
            why == 'nugget_test') {
          s.status = Status.planned;
        } else {
          s.status = Status.stopped;
        }
        s.down[sh][why] = (s.down[sh][why] ?? 0) + 1;
      } else if (s.idleLeft > 0) {
        s.idleLeft--;
        s.idleElapsed++;
        s.status = Status.waiting;
        if (s.idleElapsed > kLimits.idleGraceSec) {
          s.down[sh]['idle'] = (s.down[sh]['idle'] ?? 0) + 1;
        }
      } else {
        s.status = Status.running;
        welding = s.def.welds;
        s.cycleT += 1;
        if (s.def.welds) {
          s.spotAcc += s.def.spots / s.cycleLen;
          final n = s.spotAcc.floor();
          if (n > 0) {
            s.spotAcc -= n;
            _addSpots(s, n, p);
          }
        }
        if (s.cycleT >= s.cycleLen) _completePart(s, p);
      }
      if (s.gun != null) _gunPhysics(s, welding);
      final h2 = hmi[s.def.cell]!;
      h2.errorActive = stations.any(
        (x) => x.def.cell == s.def.cell && x.fault != null && x.fault!.stops,
      );
    }
    for (final h in hmi.values) {
      if (h.errorLatched && !h.errorActive) {
        h.quiet++;
        if (h.quiet >= 120) {
          h.errorLatched = false;
          h.resets++;
          h.quiet = 0;
        }
      }
    }
    _updateAlerts();
  }

  void _addSpots(StationState s, int n, int pos) {
    final g = s.gun!;
    s.spotsInPart += n;
    s.hourSpots[pos] += n;
    g.spotCounter += n;
    g.sinceDress += n;
    g.sinceChange += n;
    g.sinceNugget += n;
    g.kA = 8.3 + _rnd.nextDouble() * 1.4;
    g.volt = 1.85 + _rnd.nextDouble() * 0.5;
    if (g.dress == 0 && g.sinceDress >= g.dressFreq) g.dress = 1;
    if (g.change == 0 && g.sinceChange >= g.tipLife) g.change = 1;
    if (g.nugget == 3 && g.sinceNugget >= g.nuggetEvery) g.nugget = 1;
  }

  void _completePart(StationState s, int pos) {
    final rest = s.def.spots - s.spotsInPart;
    if (rest > 0) _addSpots(s, rest, pos);
    s.hourParts[pos]++;
    s.spotsInPart = 0;
    s.spotAcc = 0;
    s.cycleT = 0;
    s.cycleLen = max(
      8,
      (s.def.cycleSec * (0.94 + 0.12 * _rnd.nextDouble())).round(),
    );
    s.lastCycle = s.cycleLen;
    final g = s.gun;
    if (g != null) {
      if (g.change == 1) {
        _startPlanned(s, 'tip_change', 150);
        g.change = 2;
      } else if (g.dress == 1) {
        _startPlanned(s, 'tip_dress', 20);
        g.dress = 2;
      } else if (g.nugget == 1) {
        _startPlanned(s, 'nugget_test', 60);
        g.nugget = 2;
      }
    }
    s.idleElapsed = 0;
    final r = _rnd.nextInt(30);
    if (r == 0) {
      s.idleLeft = 150 + _rnd.nextInt(90);
    } else if (r < 10) {
      s.idleLeft = 3 + _rnd.nextInt(15);
    }
  }

  void _startPlanned(StationState s, String reason, int sec) {
    s.plannedReason = reason;
    s.plannedLeft = sec;
  }

  void _finishPlanned(StationState s) {
    final g = s.gun;
    if (g == null) return;
    switch (s.plannedReason) {
      case 'tip_dress':
        g.dress = 0;
        g.sinceDress = 0;
        break;
      case 'tip_change':
        g.change = 0;
        g.sinceChange = 0;
        g.dress = 0;
        g.sinceDress = 0;
        break;
      case 'nugget_test':
        g.nugget = 3;
        g.sinceNugget = 0;
        if (_rnd.nextInt(10) == 0)
          raise(s.def.id, Fault.nuggetFail, seconds: 60);
        break;
    }
    s.plannedReason = null;
  }

  Fault _pickFault(StationState s) {
    final pool = Fault.values
        .where((f) => !f.weldOnly || s.gun != null)
        .toList();
    return pool[_rnd.nextInt(pool.length)];
  }

  void _gunPhysics(StationState s, bool welding) {
    final g = s.gun!;
    final f = s.fault;
    var flowT = 11.6;
    if (f == Fault.flowLow) flowT = 6.8;
    if (f == Fault.waterPressure) flowT = 8.4;
    if (f == Fault.flowHigh) flowT = 13.9;
    g.flow += (flowT - g.flow) * 0.25 + (_rnd.nextDouble() - 0.5) * 0.25;
    var tempT = welding ? 40 + s.def.spots / 9 : 36.0;
    var rate = 0.03;
    if (f == Fault.overheat) {
      tempT = 92;
      rate = 0.06;
    }
    g.temp += (tempT - g.temp) * rate + (_rnd.nextDouble() - 0.5) * 0.3;
    g.ctrlOk = f != Fault.controller;
    g.programOn = hmi[s.def.cell]!.weldOn;
    if (_rnd.nextInt(2400) == 0) g.redRabbit = !g.redRabbit;
    g.flowHist.add(g.flow);
    g.tempHist.add(g.temp);
    if (g.flowHist.length > 60) g.flowHist.removeAt(0);
    if (g.tempHist.length > 60) g.tempHist.removeAt(0);
  }

  // ---------------------------------------------------------------- alerts
  List<_Cond> _conds(StationState s) {
    final c = <_Cond>[];
    final f = s.fault;
    if (f != null && f.stops && !f.derived)
      c.add(_Cond('fault', f.label, f == Fault.estop ? Sev.bad : Sev.warn));
    if (s.blocked == 'manual')
      c.add(const _Cond('manual', 'Cell is in MANUAL mode', Sev.info));
    final g = s.gun;
    if (g != null) {
      switch (flowBand(g.flow)) {
        case FlowBand.low:
          c.add(
            const _Cond('flow', 'Water flow too low (below 7.5 LPM)', Sev.bad),
          );
          break;
        case FlowBand.poor:
          c.add(
            const _Cond(
              'flow',
              'Water flow poor – not good (7.5–10 LPM)',
              Sev.warn,
            ),
          );
          break;
        case FlowBand.high:
          c.add(const _Cond('flow', 'Water flow above 13 LPM', Sev.warn));
          break;
        case FlowBand.good:
          break;
      }
      switch (tempBand(g.temp)) {
        case TempBand.hot:
          c.add(
            const _Cond('temp', 'Gun OVERHEATING (80 °C or more)', Sev.bad),
          );
          break;
        case TempBand.warm:
          c.add(
            const _Cond('temp', 'Gun getting hot (60 °C or more)', Sev.warn),
          );
          break;
        case TempBand.ok:
          break;
      }
      if (!g.ctrlOk)
        c.add(const _Cond('ctrl', 'Gun controller UNHEALTHY', Sev.bad));
      if (g.dress == 1)
        c.add(const _Cond('dress', 'Tip dressing due', Sev.warn));
      if (g.change == 1)
        c.add(const _Cond('change', 'Tip change due', Sev.warn));
      if (g.nugget == 4)
        c.add(const _Cond('nugget', 'Nugget test FAILED', Sev.bad));
      if (g.nugget == 1)
        c.add(const _Cond('nugget', 'Nugget test due', Sev.warn));
    }
    return c;
  }

  void _updateAlerts() {
    final seen = <String>{};
    for (final s in stations) {
      for (final c in _conds(s)) {
        final key = '${s.def.id}|${c.key}';
        seen.add(key);
        final cur = _open[key];
        if (cur == null || cur.text != c.text) {
          if (cur != null) cur.endedAt = now;
          final a = AlertItem(++_alertId, s.def.id, c.text, c.sev, now);
          _open[key] = a;
          alerts.insert(0, a);
        }
      }
    }
    for (final k in _open.keys.where((k) => !seen.contains(k)).toList()) {
      _open[k]!.endedAt = now;
      _open.remove(k);
    }
    if (alerts.length > 150) alerts.removeRange(150, alerts.length);
  }

  List<AlertItem> get activeAlerts => alerts.where((a) => a.active).toList();

  // ---------------------------------------------------------- maintenance
  List<MaintItem> maintenance() {
    final valves = stations.fold(
      0.0,
      (a, s) => a + (s.lifeParts + s.partsDay) * 6,
    );
    final estopMax = stations.map((s) => s.lifeEstop).reduce(max);
    final mpcbMax = stations
        .map((s) => s.lifeMpcb + s.partsDay ~/ 40)
        .reduce(max);
    final clamps = stations.fold(
      0.0,
      (a, s) => a + (s.lifeParts + s.partsDay) * 4,
    );
    final sensors = stations.fold(
      0.0,
      (a, s) => a + (s.lifeParts + s.partsDay) * 8,
    );
    final lowP = 40.0 + stations.where((s) => !s.airOk || !s.waterOk).length;
    return [
      MaintItem(
        'Solenoid valve',
        'SMC SY7000 5-port pilot valve',
        70000000,
        valves,
        'operations (all valves)',
        'Rated 70 million cycles (rubber seal).',
        'SMC USA – SY7000 series',
      ),
      MaintItem(
        'Emergency-stop button',
        'Schneider Harmony ZB4BS844',
        300000,
        estopMax.toDouble(),
        'presses (worst button)',
        'Mechanical durability 300,000 cycles.',
        'Schneider Electric eShop',
      ),
      MaintItem(
        'Motor protection breaker',
        'Schneider TeSys GV2ME',
        100000,
        mpcbMax.toDouble(),
        'operations (worst unit)',
        'Mechanical durability 100,000 cycles.',
        'GV2ME datasheet',
      ),
      const MaintItem(
        'Safety light curtain',
        'Omron F3SG-R / SR / PG',
        20,
        3.4,
        'years in service',
        'Proof-test every 20 years (a test interval, not a wear-out life).',
        'Omron F3SG specifications',
      ),
      MaintItem(
        'Part-presence sensor',
        'Omron E3ZS / E2E',
        null,
        sensors,
        'operations (counted only)',
        'No switching-cycle life is published.',
        'Omron',
      ),
      MaintItem(
        'Cylinder position sensor',
        'SMC D-A9x / Festo SME-8M',
        null,
        sensors,
        'operations (counted only)',
        'No switching-cycle life is published.',
        'SMC / Festo',
      ),
      MaintItem(
        'Clamp cylinder',
        'SMC CK1 / CKG1',
        null,
        clamps,
        'strokes (counted only)',
        'No cycle life is published.',
        'SMC',
      ),
      MaintItem(
        'Air / water pressure switch',
        'SMC ZSE / ISE',
        null,
        lowP,
        'low-pressure events (counted only)',
        'No cycle life is published.',
        'SMC',
      ),
    ];
  }
}
