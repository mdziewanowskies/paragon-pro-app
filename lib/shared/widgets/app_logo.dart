import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool withText;

  const AppLogo({super.key, this.size = 48, this.withText = false});

  @override
  Widget build(BuildContext context) {
    if (withText) {
      return SvgPicture.asset(
        'assets/images/logo_with_text.svg',
        width: size,
        height: size * (440 / 360),
      );
    }
    return SvgPicture.asset(
      'assets/images/logo.svg',
      width: size,
      height: size * (280 / 240),
    );
  }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppLogo(size: logoSize),
        const SizedBox(width: 10),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1A2837),
            ),
            children: const [
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
