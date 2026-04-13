import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // === LIGHT MODE ===
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightForeground = Color(0xFF1A1A1A);
  static const Color lightCard = Color(0xFFFAFAFA);
  static const Color lightPrimary = Color(0xFF176B47);
  static const Color lightPrimaryLight = Color(0xFF1F9663);
  static const Color lightPrimaryGlow = Color(0xFF27C17F);
  static const Color lightSecondary = Color(0xFFE3F2EC);
  static const Color lightAccent = Color(0xFF4DC98E);
  static const Color lightDestructive = Color(0xFFEF4444);
  static const Color lightMuted = Color(0xFFF5F5F5);
  static const Color lightMutedForeground = Color(0xFF737373);
  static const Color lightBorder = Color(0xFFE5E5E5);

  // === DARK MODE ===
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkForeground = Color(0xFFFAFAFA);
  static const Color darkCard = Color(0xFF1F1F1F);
  static const Color darkPrimary = Color(0xFF1F9663);
  static const Color darkPrimaryLight = Color(0xFF27C17F);
  static const Color darkAccent = Color(0xFF6DD5A8);
  static const Color darkSecondary = Color(0xFF263D33);
  static const Color darkMuted = Color(0xFF2E2E2E);
  static const Color darkBorder = Color(0xFF333333);
  static const Color darkDestructive = Color(0xFFEF4444);
  static const Color darkMutedForeground = Color(0xFF9E9E9E);

  // === GRADIENTS ===
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF176B47), Color(0xFF1F9663)],
  );

  static const LinearGradient heroGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1F9663), Color(0xFF27C17F)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4DC98E), Color(0xFF6DD5A8)],
  );

  static LinearGradient cardGradientLight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [const Color(0xFFFAFAFA), const Color(0xFFF0F0F0)],
  );

  static LinearGradient cardGradientDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [const Color(0xFF1F1F1F), const Color(0xFF181818)],
  );

  // === SHADOWS ===
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          blurRadius: 8,
          offset: const Offset(0, 2),
          color: Colors.black.withValues(alpha: 0.08),
        ),
      ];

  static List<BoxShadow> get mediumShadow => [
        BoxShadow(
          blurRadius: 16,
          offset: const Offset(0, 4),
          color: Colors.black.withValues(alpha: 0.12),
        ),
      ];

  static BoxShadow glowShadow(Color color) => BoxShadow(
        blurRadius: 32,
        color: color.withValues(alpha: 0.2),
      );
}
