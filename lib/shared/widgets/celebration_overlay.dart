import 'dart:async';
import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import '../../core/services/haptics.dart';

/// Showy, one-shot celebration: confetti from above + bouncing icon
/// + headline + optional subtitle. Auto-dismisses after [duration]
/// or on tap. Use sparingly — only for moments that genuinely deserve
/// it (premium purchase, first receipt, milestone unlock).
///
/// Usage:
/// ```dart
/// await CelebrationOverlay.show(
///   context,
///   title: 'Premium aktywowany!',
///   subtitle: 'Wszystkie funkcje są teraz odblokowane.',
/// );
/// ```
class CelebrationOverlay extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final Duration duration;

  const CelebrationOverlay({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.workspace_premium_rounded,
    this.iconColor = const Color(0xFFFFC107),
    this.duration = const Duration(seconds: 3),
  });

  /// Push as a transparent route over the current navigator and
  /// resolve when the celebration finishes. Awaitable.
  static Future<void> show(
    BuildContext context, {
    required String title,
    String? subtitle,
    IconData icon = Icons.workspace_premium_rounded,
    Color iconColor = const Color(0xFFFFC107),
    Duration duration = const Duration(seconds: 3),
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black54,
        barrierDismissible: true,
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) => CelebrationOverlay(
          title: title,
          subtitle: subtitle,
          icon: icon,
          iconColor: iconColor,
          duration: duration,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with TickerProviderStateMixin {
  late final ConfettiController _confetti;
  late final AnimationController _iconController;
  late final Animation<double> _iconScale;
  Timer? _autoClose;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _iconScale = CurvedAnimation(
      parent: _iconController,
      curve: Curves.elasticOut,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _confetti.play();
      _iconController.forward();
      Haptics.heavy();
      // Light secondary tick a beat later for layered feel.
      Future.delayed(const Duration(milliseconds: 240), Haptics.medium);
    });

    _autoClose = Timer(widget.duration, _dismiss);
  }

  void _dismiss() {
    _autoClose?.cancel();
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _autoClose?.cancel();
    _confetti.dispose();
    _iconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _dismiss,
      child: Stack(
        children: [
          // Confetti emanating downward from the top.
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirection: pi / 2,
              maxBlastForce: 18,
              minBlastForce: 6,
              emissionFrequency: 0.04,
              numberOfParticles: 24,
              gravity: 0.25,
              shouldLoop: false,
              colors: const [
                Color(0xFFFFC107),
                Color(0xFF4CAF50),
                Color(0xFF2196F3),
                Color(0xFFE91E63),
                Color(0xFF9C27B0),
              ],
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: _iconScale,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: widget.iconColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.iconColor.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        widget.icon,
                        size: 64,
                        color: widget.iconColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      widget.subtitle!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
