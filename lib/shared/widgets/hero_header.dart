import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';

/// V3 hero header — gradient + dwa rozmyte bąbelki + slot na content.
///
/// Estetyka kontynuuje ekran logowania (linear-gradient 145° green-deep
/// → green-400 + radial bubbles). Używany jako "głowa" każdego głównego
/// ekranu: Home, KSeF, Gwarancje, Analityka.
///
/// Layout:
/// ```
/// ┌────────────────────────────────────────┐
/// │  ⊙ greeting / overline                 │
/// │  XL kwota / title                      │
/// │  caption                               │
/// │  [pill] [pill]              [optional  │
/// │                              FAB]      │
/// └────────────────────────────────────────┘
/// ```
class HeroHeader extends StatelessWidget {
  /// Górny mały tekst nad tytułem (np. "Cześć, Michał 👋", "Dziś rano").
  final String? overline;

  /// Główna wartość — kwota XL, nazwa, liczba (np. "2 389,80 zł").
  final String title;

  /// Drobny tekst pod tytułem (np. "wydatków w maju · 19 paragonów").
  final String? caption;

  /// Opcjonalne pille pod captionem (np. poziom, status, ostrzeżenie).
  final List<Widget>? pills;

  /// FAB w prawym dolnym rogu hero — typowo "Skanuj".
  final Widget? fab;

  /// Minimalna wysokość headera. Audyt rekomenduje 220 px.
  final double minHeight;

  /// Kolor głównego gradientu. Domyślnie [AppColors.heroGradientV3] —
  /// ale możemy podać alternatywę (np. gold dla Plan Premium hero).
  final Gradient? gradient;

  const HeroHeader({
    super.key,
    required this.title,
    this.overline,
    this.caption,
    this.pills,
    this.fab,
    this.minHeight = 220,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      decoration: BoxDecoration(
        gradient: gradient ?? AppColors.heroGradientV3,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [AppShadows.heroGlow(AppColors.primary500)],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // ── Bąbelek 1 — prawy górny róg, jasny ────────────────
          Positioned(
            top: -60,
            right: -40,
            child: _Bubble(
              size: 220,
              color: Colors.white.withValues(alpha: 0.18),
            ),
          ),
          // ── Bąbelek 2 — lewy dolny róg, ciemny ────────────────
          Positioned(
            bottom: -80,
            left: -50,
            child: _Bubble(
              size: 200,
              color: Colors.black.withValues(alpha: 0.22),
            ),
          ),
          // ── Content ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (overline != null) ...[
                  Text(
                    overline!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
                Text(
                  title,
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    fontSize: 34,
                    height: 1.15,
                  ),
                ),
                if (caption != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    caption!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
                if (pills != null && pills!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: pills!,
                  ),
                ],
              ],
            ),
          ),
          if (fab != null)
            Positioned(
              right: AppSpacing.xl,
              bottom: AppSpacing.lg,
              child: fab!,
            ),
        ],
      ),
    );
  }
}

/// Pill chip — biała pół-transparentna kapsuła z tekstem (+ opcjonalna
/// ikona). Używany w hero do statusów typu "Poziom 3 · 295 pkt".
class HeroPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? background;
  final Color? foreground;

  const HeroPill({
    super.key,
    required this.label,
    this.icon,
    this.background,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: background ?? Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground ?? Colors.white),
            const SizedBox(width: AppSpacing.xs + 2),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: foreground ?? Colors.white,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pływający FAB do osadzenia w `HeroHeader.fab`. Biały circle 68 px z
/// gradientową ikoną, lekki cień, ripple z haptic Medium na tap.
class HeroFab extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? semanticLabel;

  const HeroFab({
    super.key,
    required this.icon,
    required this.onPressed,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 68,
            height: 68,
            child: ShaderMask(
              shaderCallback: (rect) =>
                  AppColors.statSuccess.createShader(rect),
              child: Icon(icon, size: 30, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final double size;
  final Color color;

  const _Bubble({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}
