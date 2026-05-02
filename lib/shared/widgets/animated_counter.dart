import 'package:flutter/material.dart';

/// Tweens an integer between values when [value] changes. Use for
/// points, receipt counts, levels — any number that should feel like
/// it's being incremented rather than swapped.
class AnimatedCounter extends StatelessWidget {
  final num value;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;
  final String? prefix;
  final String? suffix;
  final int fractionDigits;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 600),
    this.curve = Curves.easeOutCubic,
    this.prefix,
    this.suffix,
    this.fractionDigits = 0,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: curve,
      builder: (context, current, _) {
        final formatted = fractionDigits == 0
            ? current.round().toString()
            : current.toStringAsFixed(fractionDigits);
        return Text(
          '${prefix ?? ''}$formatted${suffix ?? ''}',
          style: style,
        );
      },
    );
  }
}
