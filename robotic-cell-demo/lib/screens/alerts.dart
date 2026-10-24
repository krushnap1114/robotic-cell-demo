import 'package:flutter/material.dart';

import '../app_state.dart';
import '../engine/defs.dart';
import '../engine/engine.dart';
import '../engine/format.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'stations.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final e = AppScope.of(context).engine;
    final active = e.activeAlerts;
    final history = e.alerts.where((a) => !a.active).take(40).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        SectionTitle(
          'Active now',
          hint: active.isEmpty
              ? 'Nothing needs attention'
              : '${active.length} need attention',
          icon: Icons.notifications_active,
        ),
        if (active.isEmpty)
          const AppCard(
            color: C.okSoft,
            child: Row(
              children: [
                Icon(Icons.check_circle, color: C.ok),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'All stations are healthy.',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        for (final a in active) ...[
          _AlertTile(a: a, now: e.now),
          const SizedBox(height: 8),
        ],
        const SectionTitle(
          'Earlier today',
          hint: 'Cleared problems',
          icon: Icons.history,
        ),
        if (history.isEmpty)
          const Text(
            'No earlier alerts yet.',
            style: TextStyle(color: C.muted),
          ),
        for (final a in history) ...[
          _AlertTile(a: a, now: e.now),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _AlertTile extends StatelessWidget {
  final AlertItem a;
  final DateTime now;
  const _AlertTile({required this.a, required this.now});

  @override
  Widget build(BuildContext context) {
    final tone = a.active ? sevTone(a.sev) : Tone.idle;
    final icon = a.sev == Sev.bad
        ? Icons.error
        : (a.sev == Sev.warn ? Icons.warning_amber_rounded : Icons.info);
    return AppCard(
      color: a.active ? toneBg(tone) : Colors.white,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => StationDetailScreen(id: a.stationId)),
      ),
      child: Row(
        children: [
          Icon(icon, color: toneFg(tone)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.text,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${stationDef(a.stationId).title} · ${hhmmss(a.at)}${a.active ? ' · ${ago(a.at, now)}' : ' · cleared ${hhmmss(a.endedAt!)}'}',
                  style: const TextStyle(fontSize: 12, color: C.muted),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: C.muted),
        ],
      ),
    );
  }
}
