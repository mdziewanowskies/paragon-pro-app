import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool inverted;

  const AppLogo({super.key, this.size = 48, this.inverted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: inverted ? null : AppColors.heroGradient,
        color: inverted ? Colors.white : null,
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: CustomPaint(
        painter: _LogoPainter(
          color: inverted
              ? Theme.of(context).colorScheme.primary
              : Colors.white,
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  final Color color;

  _LogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Receipt shape with zigzag bottom
    final receiptPath = Path()
      ..moveTo(w * 0.2, h * 0.15)
      ..lineTo(w * 0.8, h * 0.15)
      ..lineTo(w * 0.8, h * 0.72)
      // Zigzag bottom
      ..lineTo(w * 0.73, h * 0.68)
      ..lineTo(w * 0.66, h * 0.72)
      ..lineTo(w * 0.59, h * 0.68)
      ..lineTo(w * 0.5, h * 0.72)
      ..lineTo(w * 0.41, h * 0.68)
      ..lineTo(w * 0.34, h * 0.72)
      ..lineTo(w * 0.27, h * 0.68)
      ..lineTo(w * 0.2, h * 0.72)
      ..close();

    canvas.drawPath(receiptPath, paint..color = color.withValues(alpha: 0.3));

    // Letter P
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'P',
        style: TextStyle(
          color: color,
          fontSize: w * 0.4,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (w - textPainter.width) / 2,
        (h * 0.43 - textPainter.height / 2),
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AppLogoWithText extends StatelessWidget {
  final double logoSize;
  final double fontSize;

  const AppLogoWithText({
    super.key,
    this.logoSize = 40,
    this.fontSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppLogo(size: logoSize),
        const SizedBox(width: 10),
        Text(
          'ParagonPro',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
