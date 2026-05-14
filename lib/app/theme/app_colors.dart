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

  // ───────────────────────────────────────────────────────────────
  // V3 design tokens (audyt UI/Feel · maj 2026)
  //
  // Wprowadzone osobno od starych lightX/darkX żeby nie psuć
  // ekranów które jeszcze nie zostały zmigrowane. Nowe ekrany /
  // komponenty importują wyłącznie te tokeny.
  // ───────────────────────────────────────────────────────────────

  // Primary green — gradient stops
  static const Color primary500 = Color(0xFF10B981);
  static const Color primary400 = Color(0xFF34D399);
  static const Color primary300 = Color(0xFF6EE7B7);
  static const Color primary800 = Color(0xFF064E3B);
  static const Color primary900 = Color(0xFF052E1F);

  // Accents — semantyczne kolory dla stat cards / kategorii
  static const Color accentGold = Color(0xFFFBBF24);
  static const Color accentGoldDeep = Color(0xFFF59E0B);
  static const Color accentAqua = Color(0xFF06B6D4);
  static const Color accentAquaDeep = Color(0xFF0891B2);
  static const Color accentViolet = Color(0xFFA855F7);
  static const Color accentVioletDeep = Color(0xFF7C3AED);

  // Surfaces — ciemny stack
  static const Color surface0 = Color(0xFF0B1410); // app bg
  static const Color surface1 = Color(0xFF16241D); // karta default
  static const Color surface2 = Color(0xFF1F2A22); // karta hover/active
  static const Color surfaceDivider = Color(0xFF1F2A22);

  // Text scale
  static const Color textPrimary = Color(0xFFF9FAFB);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textTertiary = Color(0xFF6B7280);

  // Semantyczne — destrukcja / ostrzeżenie
  static const Color danger500 = Color(0xFFF87171);
  static const Color dangerBg = Color(0xFF7C2D2D);
  static const Color warning500 = Color(0xFFFBBF24);

  // ── Gradients V3 ────────────────────────────────────────────
  /// Główny hero gradient — kontynuacja estetyki ekranu logowania.
  /// 145° kierunek osiągamy alignment'em begin/end.
  static const LinearGradient heroGradientV3 = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary800, primary500, primary400],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient statSuccess = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary500, Color(0xFF059669)],
  );

  static const LinearGradient statInfo = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentAqua, accentAquaDeep],
  );

  static const LinearGradient statHighlight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentViolet, accentVioletDeep],
  );

  static const LinearGradient statGold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentGold, accentGoldDeep],
  );
}
