import 'package:flutter/material.dart';

import '../app_state.dart';
import '../engine/defs.dart';
import '../engine/format.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'alerts.dart';
import 'home.dart';
import 'more.dart';
import 'stations.dart';
import 'weld.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  static const _titles = [
    'Overview',
    'Stations',
    'Weld & Gun',
    'Alerts',
    'More',
  ];

  @override
  Widget build(BuildContext context) {
    final m = AppScope.of(context);
    final e = m.engine;
    final active = e.activeAlerts;
    final pages = <Widget>[
      const HomeScreen(),
      const StationsScreen(),
      const WeldScreen(),
      const AlertsScreen(),
      const MoreScreen(),
    ];
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 62,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _titles[_tab],
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            Text(
              'Shift ${shiftName(e.shift)} · ${shiftRange(e.shift)} · ${hhmmss(e.now)}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFB9C6E6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: DemoBadge()),
          ),
        ],
      ),
      body: SafeArea(top: false, child: pages[_tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: C.brand),
            label: 'Overview',
          ),
          const NavigationDestination(
            icon: Icon(Icons.factory_outlined),
            selectedIcon: Icon(Icons.factory, color: C.brand),
            label: 'Stations',
          ),
          const NavigationDestination(
            icon: Icon(Icons.bolt_outlined),
            selectedIcon: Icon(Icons.bolt, color: C.brand),
            label: 'Weld & Gun',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: active.isNotEmpty,
              label: Text('${active.length}'),
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: active.isNotEmpty,
              label: Text('${active.length}'),
              child: const Icon(Icons.notifications, color: C.brand),
            ),
            label: 'Alerts',
          ),
          const NavigationDestination(
            icon: Icon(Icons.apps_outlined),
            selectedIcon: Icon(Icons.apps, color: C.brand),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
