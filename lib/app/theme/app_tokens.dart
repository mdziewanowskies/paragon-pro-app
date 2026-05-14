/// Design tokens · V3 — radius, shadow, motion, spacing.
///
/// Komponenty importują semantyczne nazwy (np. `AppRadius.md`) zamiast
/// raw wartości. Jeśli wartość trzeba zmienić — tylko tutaj.
library;

import 'package:flutter/material.dart';

/// Border radius tokens.
class AppRadius {
  AppRadius._();

  static const double xs = 8.0;
  static const double sm = 14.0;
  static const double md = 20.0;
  static const double lg = 28.0;
  static const double full = 999.0;
}

/// Soft shadow stack — używamy wartości semantycznych, nie raw blur/offset.
class AppShadows {
  AppShadows._();

  /// Pływające drobne elementy (chips, mała pill).
  static const List<BoxShadow> sm = [
    BoxShadow(
      blurRadius: 6,
      offset: Offset(0, 2),
      color: Color(0x40000000),
    ),
  ];

  /// Karty domyślnie (paragon, faktura, gwarancja, stat).
  static const List<BoxShadow> md = [
    BoxShadow(
      blurRadius: 14,
      offset: Offset(0, 6),
      color: Color(0x59000000),
    ),
  ];

  /// Hero header, FAB, otwarty modal.
  static const List<BoxShadow> lg = [
    BoxShadow(
      blurRadius: 28,
      offset: Offset(0, 14),
      color: Color(0x80000000),
    ),
  ];

  /// Akcent glow dla hero — promień zielonego światła wokół kart akcji.
  static BoxShadow heroGlow(Color color) => BoxShadow(
        blurRadius: 28,
        offset: const Offset(0, 14),
        color: color.withValues(alpha: 0.25),
      );
}

/// Motion tokens — czas + krzywa, gotowe do wpisania w `AnimatedX`.
class AppMotion {
  AppMotion._();

  /// Tap, toggle, mikro-feedback (np. scale 0.97 przy press).
  static const Duration snap = Duration(milliseconds: 120);
  static const Curve snapCurve = Curves.easeOut;

  /// Tab change, modal entry.
  static const Duration quick = Duration(milliseconds: 200);
  static const Curve quickCurve = Curves.easeInOut;

  /// Route lista → detal (Hero animation).
  static const Duration smooth = Duration(milliseconds: 300);
  static const Curve smoothCurve = Cubic(0.4, 0.0, 0.2, 1.0);

  /// Success, +punkty, achievement — odbijający spring.
  /// Użycie: `TweenAnimationBuilder` z `Curves.elasticOut` lub
  /// `spring(stiffness: 280, damping: 18)` w `SpringSimulation`.
  static const Duration bouncy = Duration(milliseconds: 600);
  static const Curve bouncyCurve = Curves.elasticOut;

  /// Level-up, większy unlock — najmocniejsza animacja z glow.
  static const Duration ultra = Duration(milliseconds: 800);
  static const Curve ultraCurve = Curves.elasticOut;
}

/// Spacing scale — używamy wartości semantycznych zamiast raw px.
/// Wartości pasują do iOS HIG i Material 3 (skok 4 → 8 → 12 → ...).
class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double hero = 48.0;
}
