import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../shared/widgets/app_logo.dart';

/// V3 Sprint 2 — ekran "Konfigurowanie Twojej aplikacji..." pokazywany
/// raz, po pierwszym zalogowaniu nowego użytkownika.
///
/// 3-sekundowa animacja z gradient brand background'em, logo,
/// circular progress oraz cyklicznym tekstem statusu ("Wczytujemy
/// Twój profil...", "Konfigurujemy KSeF...", "Już prawie...").
/// Po zakończeniu zapisuje flagę `first_login_configured_v1` i woła
/// `onDone()`, co w `FirstLoginGate` pozwala dashboardowi się
/// zamontować.
class FirstLoginSplash extends StatefulWidget {
  final VoidCallback onDone;
  const FirstLoginSplash({super.key, required this.onDone});

  @override
  State<FirstLoginSplash> createState() => _FirstLoginSplashState();
}

class _FirstLoginSplashState extends State<FirstLoginSplash>
    with TickerProviderStateMixin {
  late final AnimationController _bgAnim;
  late final AnimationController _enter;
  late final AnimationController _progress;

  static const _statusMessages = [
    'Wczytujemy Twój profil...',
    'Konfigurujemy integrację KSeF...',
    'Synchronizujemy dane...',
    'Już prawie gotowe!',
  ];

  int _statusIndex = 0;

  @override
  void initState() {
    super.initState();
    _bgAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _progress = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..forward();

    // Rotujący komunikat statusu — co 800 ms zmiana
    for (int i = 1; i < _statusMessages.length; i++) {
      Future.delayed(Duration(milliseconds: 800 * i), () {
        if (mounted) setState(() => _statusIndex = i);
      });
    }

    // Po 3 sekundach zapisujemy flagę i kończymy
    Future.delayed(const Duration(milliseconds: 3100), () async {
      if (!mounted) return;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('first_login_configured_v1', true);
      } catch (_) {}
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _bgAnim.dispose();
    _enter.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgAnim,
        builder: (_, __) {
          // Subtle hue shift po przekątnej żeby tło "oddychało"
          final t = _bgAnim.value;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1 + t * 0.4, -1),
                end: Alignment(1, 1 - t * 0.4),
                colors: [
                  AppColors.surface0,
                  Color.lerp(AppColors.primary800, AppColors.accentAquaDeep,
                          t)!
                      .withValues(alpha: 0.85),
                  AppColors.surface0,
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  ScaleTransition(
                    scale: Tween<double>(begin: 0.85, end: 1).animate(
                      CurvedAnimation(
                          parent: _enter, curve: Curves.easeOutBack),
                    ),
                    child: FadeTransition(
                      opacity: _enter,
                      child: _LogoHero(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  FadeTransition(
                    opacity: _enter,
                    child: const Text(
                      'Konfigurujemy Twoją aplikację',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: 28,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.3),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: Text(
                        _statusMessages[_statusIndex],
                        key: ValueKey(_statusIndex),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.78),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  _ProgressRow(progress: _progress),
                  const Spacer(flex: 4),
                  FadeTransition(
                    opacity: _enter,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl),
                      child: Text(
                        'Twoje paragony, gwarancje i faktury KSeF\nw jednej, ładnej aplikacji',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.4),
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LogoHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
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
            color: AppColors.primary400.withValues(alpha: 0.5),
            blurRadius: 60,
            spreadRadius: 8,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const AppLogo(size: 70),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final AnimationController progress;
  const _ProgressRow({required this.progress});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (_, __) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: SizedBox(
                  height: 6,
                  child: Stack(
                    children: [
                      Container(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                      FractionallySizedBox(
                        widthFactor: progress.value,
                        alignment: Alignment.centerLeft,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary400,
                                AppColors.accentAqua,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${(progress.value * 100).round()}%',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Stateful flag — `true` przez pojedynczą sesję po sign-in, dopóki
/// `FirstLoginSplash` nie skończy 3s animacji. Trigger: `setShown`
/// woływane z `LoginScreen` / `RegisterScreen` po pomyślnym logowaniu.
class FirstLoginNotifier extends StateNotifier<bool> {
  FirstLoginNotifier() : super(false);

  /// Trigger po pomyślnym sign-up lub pierwszym sign-in.
  Future<void> trigger() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final done = prefs.getBool('first_login_configured_v1') ?? false;
      if (done) return;
    } catch (_) {}
    state = true;
  }

  void clear() => state = false;
}

final firstLoginSplashProvider =
    StateNotifierProvider<FirstLoginNotifier, bool>(
  (ref) => FirstLoginNotifier(),
);
