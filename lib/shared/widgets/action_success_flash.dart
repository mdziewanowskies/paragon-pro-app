import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../core/services/haptics.dart';

/// V3 Sprint 4 — krótki (1.2s) overlay z animowanym ✓ + tekstem,
/// pokazywany po zapisaniu / edycji / usunięciu zamiast typowego
/// snackbara. Daje fizyczny "to się udało" feedback.
///
/// Użycie:
/// ```dart
/// await ActionSuccessFlash.show(context, 'Zapisano!');
/// ```
class ActionSuccessFlash extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color tint;
  const ActionSuccessFlash({
    super.key,
    required this.message,
    this.icon = Icons.check_rounded,
    this.tint = AppColors.primary400,
  });

  static Future<void> show(
    BuildContext context,
    String message, {
    IconData icon = Icons.check_rounded,
    Color tint = AppColors.primary400,
  }) {
    Haptics.success();
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.18),
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) => ActionSuccessFlash(
          message: message,
          icon: icon,
          tint: tint,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  State<ActionSuccessFlash> createState() => _ActionSuccessFlashState();
}

class _ActionSuccessFlashState extends State<ActionSuccessFlash>
    with TickerProviderStateMixin {
  late final AnimationController _scale;
  late final AnimationController _ring;

  @override
  void initState() {
    super.initState();
    _scale = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
    _ring = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) Navigator.of(context, rootNavigator: true).maybePop();
    });
  }

  @override
  void dispose() {
    _scale.dispose();
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_scale, _ring]),
          builder: (_, __) {
            final s = Curves.elasticOut.transform(_scale.value);
            final ringT = Curves.easeOutCubic.transform(_ring.value);
            return Stack(
              alignment: Alignment.center,
              children: [
                // Rozszerzający się ring (efekt "ripple")
                Container(
                  width: 120 + (60 * ringT),
                  height: 120 + (60 * ringT),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.tint.withValues(
                        alpha: (1 - ringT) * 0.5,
                      ),
                      width: 2,
                    ),
                  ),
                ),
                Transform.scale(
                  scale: s,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface1,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: widget.tint.withValues(alpha: 0.35),
                          blurRadius: 32,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.tint.withValues(alpha: 0.2),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            widget.icon,
                            color: widget.tint,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.message,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
