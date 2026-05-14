import 'package:flutter/material.dart';

import '../../core/services/haptics.dart';

/// V3 Sprint 4 — micro-motion utilities żeby cała aplikacja sprawiała
/// wrażenie "magicznej i płynnej". Trzy współdzielone komponenty:
/// - StaggeredFadeIn: fade + slide-up dla item'ów listy z indeksowanym delayem
/// - PressableScale: scale-down 0.96 na tap_down + haptic feedback
/// - ScrollToTopFab: mini button pokazujący się po scrollu > threshold

/// Fade + slide-up dla pojedynczego itemu listy. Index decyduje o
/// opóźnieniu (np. 30ms × index), maksymalnie do `maxDelay`.
class StaggeredFadeIn extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration interval;
  final Duration duration;
  final Duration maxDelay;
  final double slideFrom;

  const StaggeredFadeIn({
    super.key,
    required this.index,
    required this.child,
    this.interval = const Duration(milliseconds: 32),
    this.duration = const Duration(milliseconds: 420),
    this.maxDelay = const Duration(milliseconds: 360),
    this.slideFrom = 18,
  });

  @override
  State<StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<StaggeredFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: widget.duration);
    final delay = widget.interval * widget.index;
    final capped = delay > widget.maxDelay ? widget.maxDelay : delay;
    Future.delayed(capped, () {
      if (mounted) _anim.forward();
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) {
        final t = Curves.easeOutCubic.transform(_anim.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, widget.slideFrom * (1 - t)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Tap-down scale-down dla buttonów i kart. Zwraca scale 0.96 podczas
/// trzymania palca, sprężynowy bounce na release. Plus haptic.tap().
/// Cancel-aware — jeśli user przeciągnie palec poza widget, scaluje
/// z powrotem bez wywołania `onTap`.
class PressableScale extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;
  final double scale;
  final bool haptic;
  final HitTestBehavior behavior;

  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.96,
    this.haptic = true,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 220),
      lowerBound: 0,
      upperBound: 1,
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _down(_) => _anim.forward();
  void _up(_) {
    _anim.reverse();
    if (widget.haptic) Haptics.tap();
    widget.onTap?.call();
  }

  void _cancel([_]) => _anim.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: widget.onTap != null ? _down : null,
      onTapUp: widget.onTap != null ? _up : null,
      onTapCancel: widget.onTap != null ? _cancel : null,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, child) {
          final s = 1 - (_anim.value * (1 - widget.scale));
          return Transform.scale(scale: s, child: child);
        },
        child: widget.child,
      ),
    );
  }
}

/// Floating "scroll-to-top" button pokazujący się po przekroczeniu
/// `threshold` pikseli scrollu w przypiętym `controller`. Tap →
/// animacja scroll do offsetu 0 z curve easeOutCubic.
class ScrollToTopFab extends StatefulWidget {
  final ScrollController controller;
  final double threshold;
  final EdgeInsets margin;

  const ScrollToTopFab({
    super.key,
    required this.controller,
    this.threshold = 800,
    this.margin = const EdgeInsets.only(bottom: 88, right: 16),
  });

  @override
  State<ScrollToTopFab> createState() => _ScrollToTopFabState();
}

class _ScrollToTopFabState extends State<ScrollToTopFab> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final shouldShow = widget.controller.hasClients &&
        widget.controller.offset > widget.threshold;
    if (shouldShow != _visible) {
      setState(() => _visible = shouldShow);
    }
  }

  Future<void> _scrollTop() async {
    Haptics.selection();
    await widget.controller.animateTo(
      0,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: widget.margin,
        child: AnimatedSlide(
          offset: _visible ? Offset.zero : const Offset(0, 1.6),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: const Duration(milliseconds: 240),
            child: FloatingActionButton.small(
              onPressed: _visible ? _scrollTop : null,
              heroTag: 'scroll-to-top-${widget.key ?? widget.hashCode}',
              elevation: 6,
              child: const Icon(Icons.arrow_upward_rounded, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}
