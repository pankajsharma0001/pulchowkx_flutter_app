import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class ThemeSwitcher extends StatefulWidget {
  final Widget child;

  const ThemeSwitcher({super.key, required this.child});

  static ThemeSwitcherState? of(BuildContext context) {
    return context.findAncestorStateOfType<ThemeSwitcherState>();
  }

  @override
  State<ThemeSwitcher> createState() => ThemeSwitcherState();
}

class ThemeSwitcherState extends State<ThemeSwitcher>
    with SingleTickerProviderStateMixin {
  ui.Image? _image;
  final GlobalKey _boundaryKey = GlobalKey();
  late AnimationController _animationController;
  Offset? _tapOffset;
  bool _isDarkToLight = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      reverseDuration: const Duration(milliseconds: 400),
    );
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _image = null;
        });
        _animationController.reset();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> changeTheme(VoidCallback toggle, Offset offset) async {
    try {
      final boundary =
          _boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        toggle();
        return;
      }

      // Capture current state
      final image = await boundary.toImage(
        pixelRatio: WidgetsBinding
            .instance
            .platformDispatcher
            .views
            .first
            .devicePixelRatio,
      );

      final bool isCurrentlyDark =
          Theme.of(_boundaryKey.currentContext!).brightness == Brightness.dark;

      setState(() {
        _image = image;
        _tapOffset = offset;
        _isDarkToLight = isCurrentlyDark;
      });

      // Change theme
      toggle();

      // Start animation
      _animationController.forward();
    } catch (e) {
      debugPrint('Failed to capture theme transition: $e');
      toggle();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _boundaryKey,
      child: Stack(
        textDirection: TextDirection.ltr,
        children: [
          widget.child,
          if (_image != null)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return ClipPath(
                    clipper: _CircularRevealClipper(
                      fraction: _animationController.value,
                      center:
                          _tapOffset ??
                          Offset(
                            MediaQuery.of(context).size.width / 2,
                            MediaQuery.of(context).size.height / 2,
                          ),
                      isDarkToLight: _isDarkToLight,
                    ),
                    child: RawImage(
                      image: _image,
                      fit: BoxFit.cover,
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _CircularRevealClipper extends CustomClipper<Path> {
  final double fraction;
  final Offset center;
  final bool isDarkToLight;

  _CircularRevealClipper({
    required this.fraction,
    required this.center,
    required this.isDarkToLight,
  });

  @override
  Path getClip(Size size) {
    final Path path = Path();
    // Calculate max radius from center to corners
    final double maxRadius = _calcMaxRadius(size, center);

    if (isDarkToLight) {
      // Dark -> Light (Grow): Old image is Dark (Top). New is Light (Bottom).
      // We want Light to "Grow" from center.
      // So Top Layer (Dark) must have a "Hole" that grows.
      // Hole Radius: 0 -> Max
      final double holeRadius = maxRadius * fraction;

      path.addRect(Rect.fromLTWH(0, 0, size.width, size.height));
      path.addOval(Rect.fromCircle(center: center, radius: holeRadius));
      path.fillType = PathFillType.evenOdd;
    } else {
      // Light -> Dark (Shrink): Old image is Light (Top). New is Dark (Bottom).
      // We want Light to "Shrink" into center.
      // So Top Layer (Light) is a circle that shrinks.
      // Circle Radius: Max -> 0
      final double radius = maxRadius * (1.0 - fraction);

      path.addOval(Rect.fromCircle(center: center, radius: radius));
    }

    return path;
  }

  double _calcMaxRadius(Size size, Offset center) {
    final double w = size.width;
    final double h = size.height;
    final double toTL = center.distance;
    final double toTR = (Offset(w, 0) - center).distance;
    final double toBL = (Offset(0, h) - center).distance;
    final double toBR = (Offset(w, h) - center).distance;
    return [toTL, toTR, toBL, toBR].reduce((a, b) => a > b ? a : b);
  }

  @override
  bool shouldReclip(_CircularRevealClipper oldClipper) {
    return oldClipper.fraction != fraction;
  }
}
