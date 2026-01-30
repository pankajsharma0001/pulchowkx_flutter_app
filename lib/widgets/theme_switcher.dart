import 'dart:math';
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
  Offset _tapOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
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

      // 1. Capture current state
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
      });

      // 2. Change theme
      toggle();

      // 3. Start animation
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
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          alignment: Alignment.topLeft,
          children: [
            widget.child,
            if (_image != null)
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _CircularRevealPainter(
                      image: _image!,
                      fraction: _animationController.value,
                      center: _tapOffset,
                    ),
                    size: Size.infinite,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _CircularRevealPainter extends CustomPainter {
  final ui.Image image;
  final double fraction;
  final Offset center;

  _CircularRevealPainter({
    required this.image,
    required this.fraction,
    required this.center,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate the maximum radius needed to cover the entire screen
    final double maxRadius = _calcMaxRadius(size, center);
    final double radius = maxRadius * (1 - fraction);

    if (radius > 0) {
      canvas.save();
      // Clip a circle that gets smaller
      final Path path = Path()
        ..addOval(Rect.fromCircle(center: center, radius: radius));
      canvas.clipPath(path);

      // Draw the old image
      paintImage(
        canvas: canvas,
        rect: Rect.fromLTWH(0, 0, size.width, size.height),
        image: image,
        fit: BoxFit.fill,
      );
      canvas.restore();
    }
  }

  double _calcMaxRadius(Size size, Offset center) {
    final double w = size.width;
    final double h = size.height;

    // Distance to the 4 corners
    final double d1 = center.distance; // distance to (0,0)
    final double d2 = (center - Offset(w, 0)).distance;
    final double d3 = (center - Offset(0, h)).distance;
    final double d4 = (center - Offset(w, h)).distance;

    return max(max(d1, d2), max(d3, d4));
  }

  @override
  bool shouldRepaint(_CircularRevealPainter oldDelegate) {
    return oldDelegate.fraction != fraction;
  }
}
