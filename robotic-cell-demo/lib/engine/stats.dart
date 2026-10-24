// Roll-ups used by the Overview screen (pure Dart).
import 'defs.dart';
import 'engine.dart';

class WeldStats {
  final int guns;
  final double avgKa;
  final double avgV;
  final int progOn;
  final int single;
  final int dbl;
  final StationState? hottest;
  final int warm;
  final int hot;
  final int ctrlOk;
  final int dressDue;
  final int dressing;
  final int changeDue;
  final int changing;
  final int nuggetPassed;
  final int nuggetDue;
  final int nuggetTesting;
  final int nuggetFailed;
  final int rabbitOn;
  final double avgFlow;
  final int flowLow;
  final int flowPoor;
  final int flowHigh;
  const WeldStats({
    required this.guns,
    required this.avgKa,
    required this.avgV,
    required this.progOn,
    required this.single,
    required this.dbl,
    required this.hottest,
    required this.warm,
    required this.hot,
    required this.ctrlOk,
    required this.dressDue,
    required this.dressing,
    required this.changeDue,
    required this.changing,
    required this.nuggetPassed,
    required this.nuggetDue,
    required this.nuggetTesting,
    required this.nuggetFailed,
    required this.rabbitOn,
    required this.avgFlow,
    required this.flowLow,
    required this.flowPoor,
    required this.flowHigh,
  });

  factory WeldStats.of(DemoEngine e) {
    final gs = e.guns;
    var ka = 0.0, v = 0.0, flow = 0.0;
    var prog = 0,
        dbl = 0,
        warm = 0,
        hot = 0,
        ctrl = 0,
        dd = 0,
        dg = 0,
        cd = 0,
        cg = 0,
        np = 0,
        nd = 0,
        nt = 0,
        nf = 0,
        rr = 0;
    var fl = 0, fp = 0, fh = 0;
    StationState? hottest;
    for (final s in gs) {
      final g = s.gun!;
      ka += g.kA;
      v += g.volt;
      flow += g.flow;
      if (g.programOn) prog++;
      if (g.doublePulse) dbl++;
      switch (tempBand(g.temp)) {
        case TempBand.hot:
          hot++;
          break;
        case TempBand.warm:
          warm++;
          break;
        case TempBand.ok:
          break;
      }
      switch (flowBand(g.flow)) {
        case FlowBand.low:
          fl++;
          break;
        case FlowBand.poor:
          fp++;
          break;
        case FlowBand.high:
          fh++;
          break;
        case FlowBand.good:
          break;
      }
      if (hottest == null || g.temp > hottest.gun!.temp) hottest = s;
      if (g.ctrlOk) ctrl++;
      if (g.dress == 1) dd++;
      if (g.dress == 2) dg++;
      if (g.change == 1) cd++;
      if (g.change == 2) cg++;
      if (g.nugget == 3) np++;
      if (g.nugget == 1) nd++;
      if (g.nugget == 2) nt++;
      if (g.nugget == 4) nf++;
      if (g.redRabbit) rr++;
    }
    final n = gs.isEmpty ? 1 : gs.length;
    return WeldStats(
      guns: gs.length,
      avgKa: ka / n,
      avgV: v / n,
      progOn: prog,
      single: gs.length - dbl,
      dbl: dbl,
      hottest: hottest,
      warm: warm,
      hot: hot,
      ctrlOk: ctrl,
      dressDue: dd,
      dressing: dg,
      changeDue: cd,
      changing: cg,
      nuggetPassed: np,
      nuggetDue: nd,
      nuggetTesting: nt,
      nuggetFailed: nf,
      rabbitOn: rr,
      avgFlow: flow / n,
      flowLow: fl,
      flowPoor: fp,
      flowHigh: fh,
    );
  }
}

class SafetyStats {
  final int estopPressed;
  final int estopToday;
  final int doorsOpen;
  final int electroOn;
  final int stations;
  const SafetyStats(
    this.estopPressed,
    this.estopToday,
    this.doorsOpen,
    this.electroOn,
    this.stations,
  );

  factory SafetyStats.of(DemoEngine e) {
    return SafetyStats(
      e.stations.where((s) => s.estopPressed).length,
      e.stations.fold(0, (a, s) => a + s.estopToday),
      e.stations.where((s) => !s.doorClosed).length,
      e.stations.where((s) => s.electroOn).length,
      e.stations.length,
    );
  }
}
