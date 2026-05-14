import 'dart:async';
import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/services/haptics.dart';

/// V3 Sprint 3 — pełnoekranowy dialog "Gratulacje!" po pierwszym
/// paragonie. Confetti z dwóch armatek + brand gradient + animowana
/// ikona + CTA "Zobacz moje paragony" → tab 1.
///
/// Trigger jednorazowy: flaga `first_receipt_celebrated_v1` w
/// SharedPreferences. `maybeShow()` jest no-op jeśli flaga już zapisana.
class FirstReceiptCelebrationDialog extends StatefulWidget {
  const FirstReceiptCelebrationDialog({super.key});

  static const _prefsKey = 'first_receipt_celebrated_v1';

  /// Wywoływane z `ReceiptUpload` po pomyślnym dodaniu paragonu.
  /// Sprawdza flagę i pokazuje dialog raz w życiu konta (per device).
  static Future<bool> maybeShow(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shown = prefs.getBool(_prefsKey) ?? false;
      if (shown) return false;
      await prefs.setBool(_prefsKey, true);
    } catch (_) {
      // Pref failure nie powinno blokować celebration'u — pokażemy
      // raz w sesji, w najgorszym wypadku znów się pokaże jutro.
    }
    if (!context.mounted) return false;
    await Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black87,
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 360),
        pageBuilder: (_, __, ___) => const FirstReceiptCelebrationDialog(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
    return true;
  }

  @override
  State<FirstReceiptCelebrationDialog> createState() =>
      _FirstReceiptCelebrationDialogState();
}

class _FirstReceiptCelebrationDialogState
    extends State<FirstReceiptCelebrationDialog>
    with TickerProviderStateMixin {
  late final ConfettiController _leftCannon;
  late final ConfettiController _rightCannon;
  late final ConfettiController _topCannon;
  late final AnimationController _iconAnim;
  late final AnimationController _textAnim;

  @override
  void initState() {
    super.initState();
    _leftCannon =
        ConfettiController(duration: const Duration(milliseconds: 2400));
    _rightCannon =
        ConfettiController(duration: const Duration(milliseconds: 2400));
    _topCannon =
        ConfettiController(duration: const Duration(milliseconds: 1800));
    _iconAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _textAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _leftCannon.play();
      _rightCannon.play();
      _topCannon.play();
      _iconAnim.forward();
      Haptics.heavy();
      Future.delayed(const Duration(milliseconds: 220), () {
        if (mounted) _textAnim.forward();
        Haptics.medium();
      });
      Future.delayed(const Duration(milliseconds: 480), Haptics.medium);
    });
  }

  @override
  void dispose() {
    _leftCannon.dispose();
    _rightCannon.dispose();
    _topCannon.dispose();
    _iconAnim.dispose();
    _textAnim.dispose();
    super.dispose();
  }

  void _goToReceipts() {
    Navigator.of(context, rootNavigator: true).pop();
    context.go('/?tab=1');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Gradient backdrop
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.2),
                  radius: 1.2,
                  colors: [
                    AppColors.primary800.withValues(alpha: 0.92),
                    AppColors.surface0.withValues(alpha: 0.96),
                  ],
                ),
              ),
            ),
          ),
          // Confetti — top-left cannon (kierunek w prawo-dół)
          Align(
            alignment: Alignment.topLeft,
            child: ConfettiWidget(
              confettiController: _leftCannon,
              blastDirection: pi / 4,
              maxBlastForce: 28,
              minBlastForce: 10,
              emissionFrequency: 0.03,
              numberOfParticles: 22,
              gravity: 0.18,
              shouldLoop: false,
              colors: const [
                AppColors.primary400,
                AppColors.accentAqua,
                Color(0xFFFFC107),
                Color(0xFFE91E63),
                Colors.white,
              ],
            ),
          ),
          // Confetti — top-right cannon (kierunek w lewo-dół)
          Align(
            alignment: Alignment.topRight,
            child: ConfettiWidget(
              confettiController: _rightCannon,
              blastDirection: 3 * pi / 4,
              maxBlastForce: 28,
              minBlastForce: 10,
              emissionFrequency: 0.03,
              numberOfParticles: 22,
              gravity: 0.18,
              shouldLoop: false,
              colors: const [
                AppColors.primary400,
                AppColors.accentAqua,
                Color(0xFFFFC107),
                Color(0xFFE91E63),
                Colors.white,
              ],
            ),
          ),
          // Confetti — top center (kierunek w dół)
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _topCannon,
              blastDirection: pi / 2,
              maxBlastForce: 18,
              minBlastForce: 6,
              emissionFrequency: 0.04,
              numberOfParticles: 18,
              gravity: 0.22,
              shouldLoop: false,
              colors: const [
                AppColors.primary400,
                Color(0xFFFFC107),
                Colors.white,
              ],
            ),
          ),
          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.xxl,
              ),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  ScaleTransition(
                    scale: CurvedAnimation(
                      parent: _iconAnim,
                      curve: Curves.elasticOut,
                    ),
                    child: _TrophyHero(),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FadeTransition(
                    opacity: _textAnim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.2),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: _textAnim,
                        curve: Curves.easeOutCubic,
                      )),
                      child: Column(
                        children: [
                          ShaderMask(
                            shaderCallback: (rect) => const LinearGradient(
                              colors: [
                                AppColors.primary400,
                                AppColors.accentAqua,
                              ],
                            ).createShader(rect),
                            child: const Text(
                              'Gratulacje!',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.8,
                                height: 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          const Text(
                            'Dodałeś swój pierwszy paragon!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'To pierwszy krok do pełnej kontroli nad wydatkami. '
                            'Tutaj znajdziesz wszystkie zakupy, dodasz gwarancje '
                            'i będziesz wiedział na co naprawdę idą Twoje pieniądze.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.55,
                              color: Colors.white.withValues(alpha: 0.78),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(flex: 3),
                  FadeTransition(
                    opacity: _textAnim,
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _goToReceipts,
                            icon: const Icon(
                              Icons.receipt_long_rounded,
                              size: 20,
                            ),
                            label: const Text('Zobacz moje paragony'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.primary800,
                              padding: const EdgeInsets.symmetric(
                                vertical: 18,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.full),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextButton(
                          onPressed: () => Navigator.of(context,
                                  rootNavigator: true)
                              .pop(),
                          style: TextButton.styleFrom(
                            foregroundColor:
                                Colors.white.withValues(alpha: 0.6),
                            padding: const EdgeInsets.symmetric(
                                vertical: 12),
                          ),
                          child: const Text('Może później'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrophyHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow ring
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.primary400.withValues(alpha: 0.5),
                Colors.transparent,
              ],
            ),
          ),
        ),
        Container(
          width: 132,
          height: 132,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [
                AppColors.primary400,
                AppColors.accentAqua,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary400.withValues(alpha: 0.6),
                blurRadius: 32,
                spreadRadius: 4,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.emoji_events_rounded,
            size: 72,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
