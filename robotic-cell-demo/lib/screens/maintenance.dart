import 'package:flutter/material.dart';

import '../app_state.dart';
import '../engine/engine.dart';
import '../engine/format.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final e = AppScope.of(context).engine;
    final items = e.maintenance();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preventive maintenance'),
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
          const AppCard(
            color: C.brandSoft,
            child: Text(
              'Counted operations are compared with the life published by the manufacturer for a reference model. '
              'Where a maker publishes no cycle life, only the count is shown. Counts here are demo data.',
              style: TextStyle(fontSize: 13, color: C.ink),
            ),
          ),
          const SizedBox(height: 10),
          for (final it in items) ...[
            _MaintCard(it: it),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _MaintCard extends StatelessWidget {
  final MaintItem it;
  const _MaintCard({required this.it});

  @override
  Widget build(BuildContext context) {
    final used = it.used;
    final tone = used == null
        ? Tone.idle
        : (used >= 90 ? Tone.bad : (used >= 70 ? Tone.warn : Tone.ok));
    final label = used == null
        ? 'Count only'
        : (used >= 90
              ? 'Replace soon'
              : (used >= 70 ? 'Plan service' : 'Healthy'));
    final isYears = it.unit.startsWith('years');
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  it.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              Pill(label, tone: tone),
            ],
          ),
          Text(
            it.model,
            style: const TextStyle(color: C.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          Text(
            isYears
                ? '${it.counted.toStringAsFixed(1)} ${it.unit}'
                : '${nf(it.counted)} ${it.unit}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          if (it.rated != null) ...[
            const SizedBox(height: 6),
            Bar(value: (used ?? 0) / 100, tone: tone, height: 9),
            const SizedBox(height: 3),
            Text(
              '${used!.toStringAsFixed(used < 10 ? 2 : 1)}% of the rated ${isYears ? '${it.rated!.toStringAsFixed(0)} years' : nf(it.rated!)}',
              style: const TextStyle(fontSize: 12, color: C.muted),
            ),
          ],
          const SizedBox(height: 6),
          Text(it.note, style: const TextStyle(fontSize: 12, color: C.muted)),
          Text(
            'Source: ${it.source}',
            style: const TextStyle(fontSize: 11.5, color: C.muted),
          ),
        ],
      ),
    );
  }
}
