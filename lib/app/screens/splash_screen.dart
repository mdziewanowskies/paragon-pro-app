import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../../shared/widgets/app_logo.dart';

/// V3 Sprint 2 — pełnoekranowy splash z brand gradient + logo + spinner.
///
/// Pokazywany przez ~1.2 sekundy podczas cold-start'u, zanim
/// `MaterialApp.router` zdąży zamontować dashboard. Tło zgadza się
/// z natywnym LaunchScreen (surface0) żeby uniknąć błysku przy
/// przejściu Engine Flutter → pierwsza klatka Flutter.
///
/// Po zakończeniu animacji (1200ms) wywołuje `onComplete`, co
/// w `SplashGate` zamienia overlay na rzeczywisty Material child.
class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoAnim;
  late final AnimationController _exitAnim;

  @override
  void initState() {
    super.initState();
    _logoAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _exitAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    Future.delayed(const Duration(milliseconds: 1100), () async {
      if (!mounted) return;
      await _exitAnim.forward();
      if (!mounted) return;
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _logoAnim.dispose();
    _exitAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _exitAnim,
      builder: (_, __) => Opacity(
        opacity: 1 - _exitAnim.value,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.surface0,
                const Color(0xFF0F2A1F),
                AppColors.primary800,
              ],
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Subtelna poświata radialna pod logo
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.05),
                      radius: 0.6,
                      colors: [
                        AppColors.primary400.withValues(alpha: 0.22),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleTransition(
                    scale: Tween<double>(begin: 0.7, end: 1).animate(
                      CurvedAnimation(
                        parent: _logoAnim,
                        curve: Curves.easeOutBack,
                      ),
                    ),
                    child: FadeTransition(
                      opacity: _logoAnim,
                      child: const _BrandStack(),
                    ),
                  ),
                  const SizedBox(height: 56),
                  FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _logoAnim,
                      curve: const Interval(0.5, 1, curve: Curves.easeIn),
                    ),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary400.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 48,
                child: FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _logoAnim,
                    curve: const Interval(0.6, 1, curve: Curves.easeIn),
                  ),
                  child: Text(
                    'Twój asystent paragonów i VAT',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.55),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandStack extends StatelessWidget {
  const _BrandStack();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 108,
          height: 108,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface1.withValues(alpha: 0.4),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary400.withValues(alpha: 0.4),
                blurRadius: 48,
                spreadRadius: 4,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const AppLogo(size: 72),
        ),
        const SizedBox(height: 24),
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
            children: [
              TextSpan(text: 'Paragon'),
              TextSpan(
                text: 'Pro',
                style: TextStyle(color: Color(0xFF27C17F)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Wraps a child with the splash overlay until first frame settles.
/// Used przez `ParagonProApp` jako MaterialApp.builder żeby splash
/// renderował się PO MaterialApp (ma temat i text scaler).
class SplashGate extends StatefulWidget {
  final Widget child;
  const SplashGate({super.key, required this.child});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (!_done)
          Positioned.fill(
            child: SplashScreen(
              onComplete: () {
                if (mounted) setState(() => _done = true);
              },
            ),
          ),
      ],
    );
  }
}
