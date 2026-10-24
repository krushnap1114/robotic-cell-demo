import 'dart:async';

import 'package:flutter/widgets.dart';

import 'engine/engine.dart';

class DemoUser {
  final String name;
  final String role;
  const DemoUser(this.name, this.role);
}

/// Holds the demo engine, ticks it every second and tells the screens to redraw.
class AppModel extends ChangeNotifier {
  AppModel() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (paused) return;
      engine.step(speed);
      notifyListeners();
    });
  }

  DemoEngine engine = DemoEngine();
  Timer? _timer;
  int speed = 1; // simulated seconds per real second
  bool paused = false;
  DemoUser? user;
  DateTime? lastLogin;

  static const Map<String, List<String>> _accounts = {
    'admin': ['Admin@123', 'Admin'],
    'supervisor': ['Super@123', 'Supervisor'],
    'operator': ['Oper@123', 'Operator'],
  };

  bool login(String name, String pass) {
    final a = _accounts[name.trim().toLowerCase()];
    if (a == null || a[0] != pass) return false;
    lastLogin = user == null
        ? DateTime.now().subtract(const Duration(hours: 5, minutes: 12))
        : lastLogin;
    user = DemoUser(name.trim().toLowerCase(), a[1]);
    notifyListeners();
    return true;
  }

  void logout() {
    user = null;
    notifyListeners();
  }

  bool get canControl => user != null && user!.role != 'Operator';

  void setSpeed(int s) {
    speed = s;
    notifyListeners();
  }

  void setPaused(bool p) {
    paused = p;
    notifyListeners();
  }

  void resetDemo() {
    engine = DemoEngine(seed: DateTime.now().millisecond + 1);
    notifyListeners();
  }

  void changed() => notifyListeners();

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class AppScope extends InheritedNotifier<AppModel> {
  const AppScope({super.key, required AppModel model, required super.child})
    : super(notifier: model);

  static AppModel of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found');
    return scope!.notifier!;
  }
}
