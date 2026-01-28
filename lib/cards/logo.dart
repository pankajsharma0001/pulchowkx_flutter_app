import 'package:flutter/material.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';

class LogoCard extends StatelessWidget {
  final double width;
  final double height;
  const LogoCard({super.key, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'app_logo',
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppShadows.sm,
        ),
        child: Center(
          child: Image.asset(
            'assets/icons/foreground.png',
            width: width,
            height: height,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
