import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/app_colors.dart';
import 'app_logo.dart';

/// V3 custom pull-to-refresh — bouncing logo P + dwa rozsuwające się
/// zielone bąbelki w trakcie odświeżania. Zastępuje generyczny
/// `RefreshIndicator` ze spinnerem. Audit sprint 3 motion #2:
/// "Custom logo 'P' bouncing + zielone bąbelki rozsuwające się w
/// trakcie odświeżania zamiast generycznego spinnera".
///
/// Użycie identyczne jak `RefreshIndicator`:
/// ```dart
/// ParagonRefreshIndicator(
///   onRefresh: () async { ... },
///   child: ListView(...),
/// )
/// ```
class ParagonRefreshIndicator extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final Widget child;

  /// Próg w pikselach, po którym refresh się odpala. Domyślnie 110 —
  /// trochę więcej niż standardowy 80, żeby było wyraźnie "wciągnij
  /// w dół".
  final double triggerOffset;

  const ParagonRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.triggerOffset = 110,
  });

  @override
  State<ParagonRefreshIndicator> createState() =>
      _ParagonRefreshIndicatorState();
}

class _ParagonRefreshIndicatorState extends State<ParagonRefreshIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _bouncer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final AnimationController _bubbles = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  double _pullExtent = 0;
  bool _refreshing = false;
  bool _triggered = false;

  @override
  void dispose() {
    _bouncer.dispose();
    _bubbles.dispose();
    super.dispose();
  }

  bool _onNotification(ScrollNotification n) {
    if (_refreshing) return false;
    if (n is ScrollUpdateNotification) {
      if (n.metrics.pixels < 0) {
        setState(() => _pullExtent = -n.metrics.pixels);
        // Haptic gdy przekraczamy threshold (jednokrotnie)
        if (!_triggered && _pullExtent >= widget.triggerOffset) {
          _triggered = true;
          HapticFeedback.mediumImpact();
        } else if (_triggered && _pullExtent < widget.triggerOffset) {
          _triggered = false;
        }
      } else if (_pullExtent != 0) {
        setState(() => _pullExtent = 0);
      }
    } else if (n is ScrollEndNotification) {
      if (_pullExtent >= widget.triggerOffset && !_refreshing) {
        _runRefresh();
      } else if (_pullExtent > 0) {
        setState(() => _pullExtent = 0);
      }
      _triggered = false;
    }
    return false;
  }

  Future<void> _runRefresh() async {
    setState(() {
      _refreshing = true;
      _pullExtent = widget.triggerOffset;
    });
    _bouncer.repeat(reverse: true);
    _bubbles.repeat();
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        _bouncer.stop();
        _bubbles.stop();
        setState(() {
          _refreshing = false;
          _pullExtent = 0;
        });
        HapticFeedback.lightImpact();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress =
        (_pullExtent / widget.triggerOffset).clamp(0.0, 1.0);
    final indicatorHeight = _refreshing ? widget.triggerOffset : _pullExtent;
    return Stack(
      children: [
        Positioned.fill(
          child: NotificationListener<ScrollNotification>(
            onNotification: _onNotification,
            child: widget.child,
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: indicatorHeight,
          child: ClipRect(
            child: _Indicator(
              progress: progress,
              refreshing: _refreshing,
              bouncer: _bouncer,
              bubbles: _bubbles,
              height: indicatorHeight,
            ),
          ),
        ),
      ],
    );
  }
}

class _Indicator extends StatelessWidget {
  final double progress;
  final bool refreshing;
  final AnimationController bouncer;
  final AnimationController bubbles;
  final double height;

  const _Indicator({
    required this.progress,
    required this.refreshing,
    required this.bouncer,
    required this.bubbles,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    // Logo skaluje się 0.4 → 1.0 w trakcie pull'a, a w czasie refreshu
    // bouncuje 0.85 ↔ 1.05 z spring-like easing.
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: bubbles,
          builder: (context, _) {
            final t = refreshing
                ? bubbles.value
                : (progress * 0.6).clamp(0.0, 1.0);
            return Stack(
              children: [
                Positioned(
                  left: -60 + (t * 30),
                  top: 6,
                  child: _Bubble(
                    size: 80,
                    color: AppColors.primary500
                        .withValues(alpha: 0.18 * progress),
                  ),
                ),
                Positioned(
                  right: -60 + (t * 30),
                  top: 18,
                  child: _Bubble(
                    size: 64,
                    color: AppColors.primary400
                        .withValues(alpha: 0.22 * progress),
                  ),
                ),
              ],
            );
          },
        ),
        Center(
          child: AnimatedBuilder(
            animation: bouncer,
            builder: (context, _) {
              double scale;
              if (refreshing) {
                final curved = Curves.easeInOut.transform(bouncer.value);
                scale = 0.85 + 0.20 * curved;
              } else {
                scale = 0.4 + 0.6 * progress;
              }
              return Opacity(
                opacity: progress.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary500.withValues(alpha: 0.18),
                      boxShadow: refreshing
                          ? [
                              BoxShadow(
                                color: AppColors.primary500
                                    .withValues(alpha: 0.4),
                                blurRadius: 18,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: const AppLogo(size: 28),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  final double size;
  final Color color;

  const _Bubble({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

