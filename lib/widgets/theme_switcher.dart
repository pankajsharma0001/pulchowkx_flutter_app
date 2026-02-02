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

      final bool isCurrentlyDark =
          Theme.of(_boundaryKey.currentContext!).brightness == Brightness.dark;

      if (isCurrentlyDark) {
        // Dark → Light: Capture NEW (light) theme, then expand it
        toggle();
        await Future.delayed(const Duration(milliseconds: 50));
        final image = await boundary.toImage(
          pixelRatio: WidgetsBinding
              .instance
              .platformDispatcher
              .views
              .first
              .devicePixelRatio,
        );
        setState(() {
          _image = image;
          _tapOffset = offset;
          _isDarkToLight = true;
        });
      } else {
        // Light → Dark: Capture OLD (light) theme, then shrink it
        final image = await boundary.toImage(
          pixelRatio: WidgetsBinding
              .instance
              .platformDispatcher
              .views
              .first
              .devicePixelRatio,
        );
        setState(() {
          _image = image;
          _tapOffset = offset;
          _isDarkToLight = false;
        });
        toggle();
      }

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
      // Dark → Light: Light theme EXPANDS from tap point
      // Circle grows from 0 to max
      final double radius = maxRadius * fraction;
      path.addOval(Rect.fromCircle(center: center, radius: radius));
    } else {
      // Light → Dark: Light theme SHRINKS into tap point
      // Circle shrinks from max to 0
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
