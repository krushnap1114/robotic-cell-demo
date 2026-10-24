import 'package:flutter/material.dart';

import 'app_state.dart';
import 'screens/login.dart';
import 'screens/shell.dart';
import 'ui/theme.dart';

void main() {
  runApp(const RoboticCellDemoApp());
}

class RoboticCellDemoApp extends StatefulWidget {
  const RoboticCellDemoApp({super.key});

  @override
  State<RoboticCellDemoApp> createState() => _RoboticCellDemoAppState();
}

class _RoboticCellDemoAppState extends State<RoboticCellDemoApp> {
  final AppModel _model = AppModel();

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      model: _model,
      child: MaterialApp(
        title: 'Robotic Cell I/O (Demo)',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const _Gate(),
      ),
    );
  }
}

class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    final m = AppScope.of(context);
    return m.user == null ? const LoginScreen() : const Shell();
  }
}
