import 'package:flutter/material.dart';
import '../../core/services/haptics.dart';

enum TapHaptic { none, selection, light, medium, heavy }

/// Press-and-release scale + haptic wrapper. Drop this around any
/// custom tappable surface (Cards, Containers, list rows) to give it
/// a consistent feel. For Material widgets that already render an ink
/// splash (ListTile, ElevatedButton, etc.) prefer just calling
/// [Haptics.tap] from their onPressed instead.
class TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final TapHaptic haptic;
  final double pressedScale;
  final Duration duration;
  final Curve curve;

  /// Optional VoiceOver / TalkBack label. When set, replaces whatever
  /// the child element would announce by default.
  final String? semanticsLabel;

  /// Optional VoiceOver / TalkBack hint announced after the label
  /// (e.g. 'opens warranty details').
  final String? semanticsHint;

  const TapScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.haptic = TapHaptic.light,
    this.pressedScale = 0.97,
    this.duration = const Duration(milliseconds: 110),
    this.curve = Curves.easeOutCubic,
    this.semanticsLabel,
    this.semanticsHint,
  });

  /// Backwards-compat shim for old call sites that used `enableHaptic`.
  @Deprecated('Use haptic: TapHaptic.light/none')
  factory TapScale.legacy({
    Key? key,
    required Widget child,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    bool enableHaptic = true,
  }) =>
      TapScale(
        key: key,
        onTap: onTap,
        onLongPress: onLongPress,
        haptic: enableHaptic ? TapHaptic.light : TapHaptic.none,
        child: child,
      );

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    reverseDuration: widget.duration,
  );

  late final Animation<double> _scale = Tween<double>(
    begin: 1.0,
    end: widget.pressedScale,
  ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _fireHaptic() {
    switch (widget.haptic) {
      case TapHaptic.none:
        break;
      case TapHaptic.selection:
        Haptics.selection();
        break;
      case TapHaptic.light:
        Haptics.tap();
        break;
      case TapHaptic.medium:
        Haptics.medium();
        break;
      case TapHaptic.heavy:
        Haptics.heavy();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tappable = widget.onTap != null || widget.onLongPress != null;
    final core = MouseRegion(
      cursor: tappable ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: tappable ? (_) => _controller.forward() : null,
        onTapUp: tappable
            ? (_) {
                _controller.reverse();
                _fireHaptic();
              }
            : null,
        onTapCancel: tappable ? () => _controller.reverse() : null,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress != null
            ? () {
                Haptics.medium();
                widget.onLongPress!();
              }
            : null,
        child: ScaleTransition(
          scale: _scale,
          child: widget.child,
        ),
      ),
    );

    if (widget.semanticsLabel == null && widget.semanticsHint == null) {
      return core;
    }
    return Semantics(
      button: tappable,
      label: widget.semanticsLabel,
      hint: widget.semanticsHint,
      excludeSemantics: widget.semanticsLabel != null,
      child: core,
    );
  }
}
