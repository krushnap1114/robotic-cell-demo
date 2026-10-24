import 'package:flutter/material.dart';

class C {
  static const ink = Color(0xFF0B1B33);
  static const muted = Color(0xFF435468);
  static const line = Color(0xFFD7DFEB);
  static const canvas = Color(0xFFF1F5F9);
  static const navy = Color(0xFF0B1A45);
  static const brand = Color(0xFF1D4ED8);
  static const brandSoft = Color(0xFFE3EBFF);
  static const ok = Color(0xFF15803D);
  static const okSoft = Color(0xFFDCFCE7);
  static const warn = Color(0xFFD97706);
  static const warnSoft = Color(0xFFFEF3C7);
  static const bad = Color(0xFFDC2626);
  static const badSoft = Color(0xFFFEE2E2);
  static const idle = Color(0xFF64748B);
  static const idleSoft = Color(0xFFE5EAF1);
  static const teal = Color(0xFF0F766E);
  static const tealSoft = Color(0xFFCCFBF1);
  static const sky = Color(0xFF0369A1);
  static const skySoft = Color(0xFFE0F2FE);
}

enum Tone { ok, warn, bad, info, idle, teal, sky }

Color toneFg(Tone t) {
  switch (t) {
    case Tone.ok:
      return C.ok;
    case Tone.warn:
      return C.warn;
    case Tone.bad:
      return C.bad;
    case Tone.info:
      return C.brand;
    case Tone.idle:
      return C.idle;
    case Tone.teal:
      return C.teal;
    case Tone.sky:
      return C.sky;
  }
}

Color toneBg(Tone t) {
  switch (t) {
    case Tone.ok:
      return C.okSoft;
    case Tone.warn:
      return C.warnSoft;
    case Tone.bad:
      return C.badSoft;
    case Tone.info:
      return C.brandSoft;
    case Tone.idle:
      return C.idleSoft;
    case Tone.teal:
      return C.tealSoft;
    case Tone.sky:
      return C.skySoft;
  }
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: C.brand,
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: C.canvas,
    appBarTheme: const AppBarTheme(
      backgroundColor: C.navy,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: C.brandSoft,
    ),
    dividerColor: C.line,
  );
}
