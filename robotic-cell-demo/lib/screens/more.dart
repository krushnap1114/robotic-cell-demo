import 'package:flutter/material.dart';

import '../app_state.dart';
import '../engine/format.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'downtime.dart';
import 'maintenance.dart';
import 'planning.dart';
import 'safety.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  Widget _tile(
    BuildContext context,
    IconData icon,
    String title,
    String sub,
    Widget page,
  ) {
    return AppCard(
      onTap: () =>
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: C.brandSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: C.brand),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15.5,
                  ),
                ),
                Text(
                  sub,
                  style: const TextStyle(color: C.muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: C.muted),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = AppScope.of(context);
    final e = m.engine;
    final u = m.user!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        AppCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: C.brand,
                child: Text(
                  u.name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      '${u.role} · last login ${m.lastLogin == null ? '—' : hhmm(m.lastLogin!)}',
                      style: const TextStyle(color: C.muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: m.logout,
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
        const SectionTitle('Screens', icon: Icons.apps),
        _tile(
          context,
          Icons.hourglass_bottom,
          'Downtime',
          'Hours and minutes by reason, by shift',
          const DowntimeScreen(),
        ),
        const SizedBox(height: 8),
        _tile(
          context,
          Icons.shield,
          'Safety & HMI',
          'Emergency stops, doors, HMI panels, reset',
          const SafetyScreen(),
        ),
        const SizedBox(height: 8),
        _tile(
          context,
          Icons.event_note,
          'Weekly plan',
          'Feeding plan, daily split, efficiency',
          const PlanningScreen(),
        ),
        const SizedBox(height: 8),
        _tile(
          context,
          Icons.build_circle,
          'Preventive maintenance',
          'Counted operations against rated life',
          const MaintenanceScreen(),
        ),
        const SectionTitle(
          'Demo controls',
          hint: 'For showing the app to the client',
          icon: Icons.science,
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Simulation speed',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment<int>(value: 1, label: Text('1×')),
                  ButtonSegment<int>(value: 5, label: Text('5×')),
                  ButtonSegment<int>(value: 20, label: Text('20×')),
                  ButtonSegment<int>(value: 60, label: Text('60×')),
                ],
                selected: {m.speed},
                onSelectionChanged: (s) => m.setSpeed(s.first),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Random problems'),
                subtitle: const Text('Faults appear by themselves'),
                value: e.autoFaults,
                onChanged: (v) {
                  e.autoFaults = v;
                  m.changed();
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Pause simulation'),
                value: m.paused,
                onChanged: m.setPaused,
              ),
              const Divider(),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.clear_all, size: 18),
                    label: const Text('Clear all problems'),
                    onPressed: () {
                      e.clearAllFaults();
                      m.changed();
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.restart_alt, size: 18),
                    label: const Text('Restart demo'),
                    onPressed: () {
                      m.resetDemo();
                      demoSnack(context, 'Demo restarted with fresh data');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Tip: open a station and tap a problem chip (Admin / Supervisor) to show how the app reacts.',
                style: TextStyle(fontSize: 12, color: C.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Center(child: DemoBadge()),
        const SizedBox(height: 6),
        const Center(
          child: Text(
            'Robotic Cell I/O · demo build 1.0',
            style: TextStyle(fontSize: 12, color: C.muted),
          ),
        ),
      ],
    );
  }
}
