import 'package:flutter/material.dart';

/// V3 theme extension trzymający kolory zależne od trybu (dark/light).
/// Komponenty czytają je przez `context.colors.surface1` zamiast
/// hardcodowanego `AppColors.surface1`. Dzięki temu zmiana motywu
/// (Settings → Motyw) propaguje się przez całe drzewo widgetów bez
/// rebuildu na ręcznych warunkach.
///
/// Audyt 9 — "Motyw: jasny / ciemny / system. Dziś app jest tylko
/// dark — to ok, ale daj wybór".
@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  /// Tło aplikacji (najgłębsze).
  final Color surface0;

  /// Karty default — paragon, faktura, gwarancja, stat.
  final Color surface1;

  /// Hover/active state karty oraz drobne wnęki (pill background,
  /// number badge).
  final Color surface2;

  /// 1 px linie wewnątrz kart i sekcji.
  final Color surfaceDivider;

  /// Główny kolor tekstu — tytuły, kwoty.
  final Color textPrimary;

  /// Drobny tekst — captions, metadata.
  final Color textSecondary;

  /// Disabled / mini-print.
  final Color textTertiary;

  const AppThemeColors({
    required this.surface0,
    required this.surface1,
    required this.surface2,
    required this.surfaceDivider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
  });

  /// Wariant ciemny — V3 dark stack (z app_colors.dart).
  static const dark = AppThemeColors(
    surface0: Color(0xFF0B1410),
    surface1: Color(0xFF16241D),
    surface2: Color(0xFF1F2A22),
    surfaceDivider: Color(0xFF1F2A22),
    textPrimary: Color(0xFFF9FAFB),
    textSecondary: Color(0xFF9CA3AF),
    textTertiary: Color(0xFF6B7280),
  );

  /// Wariant jasny — biało-zielono-szary stack. Akcenty (primary,
  /// gold, aqua, violet) pozostają niezmienione bo dobrze działają
  /// w obu trybach.
  static const light = AppThemeColors(
    surface0: Color(0xFFF7F8F7),
    surface1: Color(0xFFFFFFFF),
    surface2: Color(0xFFEFF3F1),
    surfaceDivider: Color(0xFFE4E9E6),
    textPrimary: Color(0xFF0F1916),
    textSecondary: Color(0xFF5D6B65),
    textTertiary: Color(0xFF8A958F),
  );

  @override
  AppThemeColors copyWith({
    Color? surface0,
    Color? surface1,
    Color? surface2,
    Color? surfaceDivider,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
  }) {
    return AppThemeColors(
      surface0: surface0 ?? this.surface0,
      surface1: surface1 ?? this.surface1,
      surface2: surface2 ?? this.surface2,
      surfaceDivider: surfaceDivider ?? this.surfaceDivider,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
    );
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) return this;
    return AppThemeColors(
      surface0: Color.lerp(surface0, other.surface0, t)!,
      surface1: Color.lerp(surface1, other.surface1, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      surfaceDivider:
          Color.lerp(surfaceDivider, other.surfaceDivider, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary:
          Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary:
          Color.lerp(textTertiary, other.textTertiary, t)!,
    );
  }
}

/// Cukrowy getter — `context.colors.surface1` zamiast pisania
/// `Theme.of(context).extension<AppThemeColors>()!.surface1`.
extension AppColorsContextX on BuildContext {
  AppThemeColors get colors =>
      Theme.of(this).extension<AppThemeColors>() ?? AppThemeColors.dark;
}
