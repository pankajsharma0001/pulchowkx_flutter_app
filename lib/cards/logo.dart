import 'package:flutter/material.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';

class LogoCard extends StatelessWidget {
  final double width;
  final double height;
  final bool useHero;

  const LogoCard({
    super.key,
    required this.width,
    required this.height,
    this.useHero = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.sm,
      ),
      child: Center(
        child: Image.asset(
          'assets/icons/logo.png',
          width: width,
          height: height,
          fit: BoxFit.contain,
        ),
      ),
    );

    if (useHero) {
      return Hero(tag: 'app_logo', child: content);
    }

    return content;
  }
}
