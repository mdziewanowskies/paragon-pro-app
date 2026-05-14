import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';

/// Semantyczny wariant karty stat — każdy nawiązuje do innego "języka":
/// success = wydatki (pierwszorzędny), info = paragony (drugorzędny),
/// highlight = gwarancje / akcent ostrzegawczy, gold = top kategoria /
/// premium feel.
enum StatCardVariant { success, info, highlight, gold }

/// V3 stat card — używana w gridzie 2×2 na dashboardzie. Każda karta
/// ma swój semantyczny kolor (audyt: "primary green tylko jako akcent,
/// karty stat dostają 4 różne kolory").
///
/// Layout:
/// ```
/// ┌──────────────┐
/// │ ⊙ icon       │
/// │ XL value     │
/// │ caption      │
/// │ ▲ mini-delta │
/// └──────────────┘
/// ```
class StatCard extends StatelessWidget {
  /// Główna wartość, np. "2 390 zł", "19", "Żywność".
  final String value;

  /// Krótki opis pod wartością, np. "wydatki w maju".
  final String caption;

  /// Opcjonalna mini-delta — np. "▲ 12% wzgl. kwietnia" lub "+5 w tym
  /// tygodniu". Renderuje się 11pt pod captionem.
  final String? delta;

  /// Ikona w okręgu w lewym górnym rogu — symbol semantyczny (typowo
  /// Material `Icons.check_circle`, `Icons.receipt_long`, etc.).
  final IconData icon;

  /// Wariant kolorystyczny.
  final StatCardVariant variant;

  /// Opcjonalny callback. Bez niego karta jest tylko prezentacyjna.
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.value,
    required this.caption,
    required this.icon,
    required this.variant,
    this.delta,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _palettes[variant]!;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md + 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md + 2),
        child: Ink(
          decoration: BoxDecoration(
            gradient: palette.gradient,
            borderRadius: BorderRadius.circular(AppRadius.md + 2),
            boxShadow: AppShadows.md,
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ikona w okręgu top-left (subtle, ~18 px ikona w 30 px circle)
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.22),
                ),
                child: Icon(icon, size: 16, color: palette.iconColor),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 24,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  color: palette.valueColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: palette.captionColor,
                ),
              ),
              if (delta != null) ...[
                const SizedBox(height: 4),
                Text(
                  delta!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: palette.deltaColor,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static const Map<StatCardVariant, _StatPalette> _palettes = {
    StatCardVariant.success: _StatPalette(
      gradient: AppColors.statSuccess,
      iconColor: Colors.white,
      valueColor: Colors.white,
      captionColor: Color(0xCCFFFFFF),
      deltaColor: Color(0xE6FFFFFF),
    ),
    StatCardVariant.info: _StatPalette(
      gradient: AppColors.statInfo,
      iconColor: Colors.white,
      valueColor: Colors.white,
      captionColor: Color(0xCCFFFFFF),
      deltaColor: Color(0xE6FFFFFF),
    ),
    StatCardVariant.highlight: _StatPalette(
      gradient: AppColors.statHighlight,
      iconColor: Colors.white,
      valueColor: Colors.white,
      captionColor: Color(0xCCFFFFFF),
      deltaColor: Color(0xE6FFFFFF),
    ),
    // Gold świadomie ma ciemny tekst — żółto-pomarańczowy gradient ma
    // niski kontrast z bielą, czytelniej z #052E1F (primary900).
    StatCardVariant.gold: _StatPalette(
      gradient: AppColors.statGold,
      iconColor: AppColors.primary900,
      valueColor: AppColors.primary900,
      captionColor: Color(0xCC052E1F),
      deltaColor: Color(0xE6052E1F),
    ),
  };
}

class _StatPalette {
  final LinearGradient gradient;
  final Color iconColor;
  final Color valueColor;
  final Color captionColor;
  final Color deltaColor;

  const _StatPalette({
    required this.gradient,
    required this.iconColor,
    required this.valueColor,
    required this.captionColor,
    required this.deltaColor,
  });
}
