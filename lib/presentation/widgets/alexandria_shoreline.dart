import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Animated Alexandria horizon for the splash screen: a low sun, the Qaitbay
/// citadel with a lighthouse beam sweeping the sky, and three layers of
/// Mediterranean waves drifting at different speeds.
///
/// Honours the platform "reduce motion" setting by painting a still frame.
class AlexandriaShoreline extends StatefulWidget {
  const AlexandriaShoreline({
    super.key,
    this.height = 150,
    this.period = const Duration(seconds: 9),
  });

  final double height;

  /// Time for one full wave cycle; the beam sweeps once per cycle.
  final Duration period;

  @override
  State<AlexandriaShoreline> createState() => _AlexandriaShorelineState();
}

class _AlexandriaShorelineState extends State<AlexandriaShoreline>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _ctrl
        ..stop()
        ..value = 0.25;
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) =>
                CustomPaint(painter: ShorelinePainter(progress: _ctrl.value)),
          ),
        ),
      ),
    );
  }
}

/// Paints one frame of the shoreline. [progress] runs 0 → 1 per cycle.
class ShorelinePainter extends CustomPainter {
  ShorelinePainter({required this.progress});

  final double progress;

  static const Color navy = Color(0xFF1F3A5F);
  static const Color sea = Color(0xFF2E6E8E);
  static const Color sand = Color(0xFF8C7B5E);
  static const Color sun = Color(0xFFE9B872);

  /// Height of a sine wave layer at [x]; exposed for tests.
  static double waveY({
    required double x,
    required double width,
    required double baseline,
    required double amplitude,
    required double wavelengths,
    required double phase,
  }) {
    final t = (x / width) * wavelengths * 2 * math.pi;
    return baseline + amplitude * math.sin(t + phase);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final turn = progress * 2 * math.pi;
    final horizon = h * 0.48;

    // Low sun behind the horizon.
    final sunCenter = Offset(w * 0.22, horizon - 4);
    canvas.drawCircle(
      sunCenter,
      h * 0.42,
      Paint()
        ..shader = RadialGradient(
          colors: [sun.withValues(alpha: 0.38), sun.withValues(alpha: 0.0)],
        ).createShader(Rect.fromCircle(center: sunCenter, radius: h * 0.42)),
    );
    canvas.drawCircle(
      sunCenter,
      h * 0.11,
      Paint()..color = sun.withValues(alpha: 0.55),
    );

    // Lighthouse beam: a soft wedge sweeping across the sky.
    final lamp = Offset(w * 0.78, horizon - h * 0.30);
    final sweep = math.sin(turn) * 0.9; // radians either side of vertical
    final beamAngle = -math.pi / 2 + sweep;
    const spread = 0.16;
    final reach = w * 0.55;
    final beam = Path()
      ..moveTo(lamp.dx, lamp.dy)
      ..lineTo(
        lamp.dx + reach * math.cos(beamAngle - spread),
        lamp.dy + reach * math.sin(beamAngle - spread),
      )
      ..lineTo(
        lamp.dx + reach * math.cos(beamAngle + spread),
        lamp.dy + reach * math.sin(beamAngle + spread),
      )
      ..close();
    canvas.drawPath(
      beam,
      Paint()
        ..shader = RadialGradient(
          colors: [sun.withValues(alpha: 0.45), sun.withValues(alpha: 0.0)],
        ).createShader(Rect.fromCircle(center: lamp, radius: reach)),
    );

    _paintCitadel(canvas, w, h, horizon);
    canvas.drawCircle(lamp, 2.6, Paint()..color = sun);

    // Three wave layers, back to front.
    _paintWave(
      canvas,
      size,
      baseline: horizon + h * 0.04,
      amplitude: h * 0.035,
      wavelengths: 1.3,
      phase: turn,
      color: sea.withValues(alpha: 0.28),
    );
    _paintWave(
      canvas,
      size,
      baseline: horizon + h * 0.16,
      amplitude: h * 0.045,
      wavelengths: 1.8,
      phase: -turn * 2 + 1.1,
      color: sea.withValues(alpha: 0.42),
    );
    _paintWave(
      canvas,
      size,
      baseline: horizon + h * 0.30,
      amplitude: h * 0.04,
      wavelengths: 2.4,
      phase: turn * 3 + 2.3,
      color: navy.withValues(alpha: 0.62),
    );
  }

  void _paintCitadel(Canvas canvas, double w, double h, double horizon) {
    final paint = Paint()..color = navy.withValues(alpha: 0.78);
    final base = horizon + h * 0.06;
    final left = w * 0.66;
    final right = w * 0.92;
    final wallTop = horizon - h * 0.10;

    // Outer wall with crenellations.
    final wall = Path()..moveTo(left, base);
    wall.lineTo(left, wallTop);
    const merlons = 9;
    final step = (right - left) / (merlons * 2);
    for (var i = 0; i < merlons * 2; i++) {
      final x = left + step * i;
      final y = i.isEven ? wallTop - h * 0.025 : wallTop;
      wall
        ..lineTo(x, y)
        ..lineTo(x + step, y);
    }
    wall
      ..lineTo(right, base)
      ..close();
    canvas.drawPath(wall, paint);

    // Corner towers.
    for (final x in [left - w * 0.012, right - w * 0.018]) {
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(
            x,
            wallTop - h * 0.07,
            w * 0.03,
            base - wallTop + h * 0.07,
          ),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        ),
        paint,
      );
    }

    // Central keep with the lighthouse lantern on top.
    final keepLeft = w * 0.745;
    final keepWidth = w * 0.07;
    final keepTop = horizon - h * 0.22;
    canvas.drawRect(
      Rect.fromLTWH(keepLeft, keepTop, keepWidth, base - keepTop),
      paint,
    );
    final lanternWidth = keepWidth * 0.42;
    final lanternLeft = keepLeft + (keepWidth - lanternWidth) / 2;
    canvas.drawRect(
      Rect.fromLTWH(lanternLeft, keepTop - h * 0.07, lanternWidth, h * 0.07),
      paint,
    );

    // A thin sand strip where the citadel meets the sea.
    canvas.drawRect(
      Rect.fromLTWH(left - w * 0.03, base - 2, right - left + w * 0.06, 3),
      Paint()..color = sand.withValues(alpha: 0.35),
    );
  }

  void _paintWave(
    Canvas canvas,
    Size size, {
    required double baseline,
    required double amplitude,
    required double wavelengths,
    required double phase,
    required Color color,
  }) {
    final path = Path()..moveTo(0, size.height);
    for (double x = 0; x <= size.width; x += 4) {
      path.lineTo(
        x,
        waveY(
          x: x,
          width: size.width,
          baseline: baseline,
          amplitude: amplitude,
          wavelengths: wavelengths,
          phase: phase,
        ),
      );
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(ShorelinePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
