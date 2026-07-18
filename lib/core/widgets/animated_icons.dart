import 'dart:math';
import 'package:flutter/material.dart';

enum LottieAnimations {
  compass, 
  camera, 
  trophy, 
  route, 
  cloud, 
  radar, 
  chat, 
}

class AnimatedLottieIcon extends StatefulWidget {
  final LottieAnimations animation;
  final double size;
  final Color color;
  final Color? secondaryColor;

  const AnimatedLottieIcon({
    super.key,
    required this.animation,
    this.size = 80,
    this.color = Colors.white,
    this.secondaryColor,
  });

  @override
  State<AnimatedLottieIcon> createState() => _AnimatedLottieIconState();
}

class _AnimatedLottieIconState extends State<AnimatedLottieIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: _durationFor(widget.animation),
    )..repeat();
  }

  Duration _durationFor(LottieAnimations a) {
    switch (a) {
      case LottieAnimations.compass:
        return const Duration(milliseconds: 3500);
      case LottieAnimations.camera:
        return const Duration(milliseconds: 2200);
      case LottieAnimations.trophy:
        return const Duration(milliseconds: 1800);
      case LottieAnimations.route:
        return const Duration(milliseconds: 2600);
      case LottieAnimations.cloud:
        return const Duration(milliseconds: 2400);
      case LottieAnimations.radar:
        return const Duration(milliseconds: 2500);
      case LottieAnimations.chat:
        return const Duration(milliseconds: 1600);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return CustomPaint(
          size: Size.square(widget.size),
          painter: _LottiePainter(
            type: widget.animation,
            progress: _ctrl.value,
            primary: widget.color,
            secondary: widget.secondaryColor ?? widget.color,
          ),
        );
      },
    );
  }
}

class _LottiePainter extends CustomPainter {
  final LottieAnimations type;
  final double progress; 
  final Color primary;
  final Color secondary;

  _LottiePainter({
    required this.type,
    required this.progress,
    required this.primary,
    required this.secondary,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final p = Paint()
      ..color = primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.1
      ..strokeCap = StrokeCap.round;
    final pFill = Paint()
      ..color = primary
      ..style = PaintingStyle.fill;

    switch (type) {
      case LottieAnimations.compass:
        _drawCompass(canvas, center, radius, p, pFill);
        break;
      case LottieAnimations.camera:
        _drawCamera(canvas, center, radius, p, pFill);
        break;
      case LottieAnimations.trophy:
        _drawTrophy(canvas, center, radius, p, pFill);
        break;
      case LottieAnimations.route:
        _drawRoute(canvas, center, radius, p, pFill);
        break;
      case LottieAnimations.cloud:
        _drawCloud(canvas, center, radius, p, pFill);
        break;
      case LottieAnimations.radar:
        _drawRadar(canvas, center, radius, p, pFill);
        break;
      case LottieAnimations.chat:
        _drawChat(canvas, center, radius, p, pFill);
        break;
    }
  }

  void _drawCompass(
      Canvas canvas, Offset c, double r, Paint p, Paint pFill) {
    
    canvas.drawCircle(c, r * 0.85, p);
    
    for (var i = 0; i < 4; i++) {
      final a = i * pi / 2;
      canvas.drawLine(
        c + Offset(cos(a), sin(a)) * (r * 0.65),
        c + Offset(cos(a), sin(a)) * (r * 0.78),
        p,
      );
    }
    
    final angle = progress * 2 * pi;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    final north = Paint()..color = primary;
    final south = Paint()..color = secondary.withValues(alpha: 0.4);
    final path = Path()
      ..moveTo(0, -r * 0.55)
      ..lineTo(r * 0.1, 0)
      ..lineTo(0, r * 0.55)
      ..lineTo(-r * 0.1, 0)
      ..close();
    canvas.drawPath(path, north);
    final path2 = Path()
      ..moveTo(0, r * 0.55)
      ..lineTo(r * 0.1, 0)
      ..lineTo(-r * 0.1, 0)
      ..close();
    canvas.drawPath(path2, south);
    canvas.restore();
    
    canvas.drawCircle(c, r * 0.1, pFill);
  }

  void _drawCamera(
      Canvas canvas, Offset c, double r, Paint p, Paint pFill) {
    
    final blades = 6;
    final openAmount =
        0.5 + 0.5 * sin(progress * 2 * pi); 
    final rotation = progress * 2 * pi / blades;
    for (var i = 0; i < blades; i++) {
      final angle = i * 2 * pi / blades + rotation;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(angle);
      final blade = Path()
        ..moveTo(0, 0)
        ..lineTo(r * 0.6, r * 0.1)
        ..lineTo(r * 0.5, -r * 0.2 * openAmount)
        ..close();
      canvas.drawPath(blade, pFill..color = primary);
      canvas.restore();
    }
    
    canvas.drawCircle(c, r * 0.12, Paint()..color = Colors.white);
  }

  void _drawTrophy(
      Canvas canvas, Offset c, double r, Paint p, Paint pFill) {
    
    final scale = 1.0 + 0.08 * sin(progress * 2 * pi);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(scale);

    
    final cupRect = Rect.fromCenter(
      center: Offset(0, -r * 0.15),
      width: r * 0.7,
      height: r * 0.55,
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        cupRect,
        topLeft: Radius.circular(r * 0.1),
        topRight: Radius.circular(r * 0.1),
        bottomLeft: Radius.circular(r * 0.18),
        bottomRight: Radius.circular(r * 0.18),
      ),
      pFill,
    );
    
    canvas.drawArc(
      Rect.fromCenter(center: Offset(-r * 0.35, -r * 0.15),
          width: r * 0.3, height: r * 0.4),
      pi / 2, pi, false,
      p..style = PaintingStyle.stroke,
    );
    canvas.drawArc(
      Rect.fromCenter(center: Offset(r * 0.35, -r * 0.15),
          width: r * 0.3, height: r * 0.4),
      -pi / 2, pi, false,
      p,
    );
    
    canvas.drawRect(
      Rect.fromCenter(center: Offset(0, r * 0.2), width: r * 0.12, height: r * 0.18),
      pFill,
    );
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0, r * 0.42),
            width: r * 0.5, height: r * 0.12),
        Radius.circular(r * 0.04),
      ),
      pFill,
    );
    
    final spark = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(0, -r * 0.4), r * 0.07, spark);
    canvas.restore();
    p.style = PaintingStyle.fill;
  }

  void _drawRoute(
      Canvas canvas, Offset c, double r, Paint p, Paint pFill) {
    
    final path = Path();
    path.moveTo(c.dx - r * 0.6, c.dy + r * 0.2);
    path.cubicTo(
      c.dx - r * 0.3, c.dy - r * 0.4,
      c.dx + r * 0.1, c.dy + r * 0.4,
      c.dx + r * 0.4, c.dy - r * 0.1,
    );
    path.cubicTo(
      c.dx + r * 0.5, c.dy - r * 0.3,
      c.dx + r * 0.7, c.dy,
      c.dx + r * 0.6, c.dy + r * 0.3,
    );
    canvas.drawPath(path, p);
    
    final metric = path.computeMetrics().first;
    final tan = metric.getTangentForOffset(metric.length * progress);
    if (tan != null) {
      canvas.drawCircle(tan.position, r * 0.13, pFill);
      canvas.drawCircle(
        tan.position,
        r * 0.22,
        Paint()
          ..color = primary.withValues(alpha: 0.25)
          ..style = PaintingStyle.fill,
      );
    }
  }

  void _drawCloud(
      Canvas canvas, Offset c, double r, Paint p, Paint pFill) {
    
    final cloudPaint = Paint()..color = primary.withValues(alpha: 0.85);
    final pOutline = Paint()
      ..color = primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.08;
    final body = Path()
      ..addOval(Rect.fromCenter(
          center: c + Offset(-r * 0.25, 0), width: r * 0.7, height: r * 0.55))
      ..addOval(Rect.fromCenter(
          center: c + Offset(0, -r * 0.2), width: r * 0.65, height: r * 0.6))
      ..addOval(Rect.fromCenter(
          center: c + Offset(r * 0.3, 0), width: r * 0.6, height: r * 0.5));
    canvas.drawPath(body, cloudPaint);
    canvas.drawPath(body, pOutline);
    
    canvas.save();
    canvas.translate(0, sin(progress * 2 * pi) * r * 0.05);
    canvas.restore();
    
    for (var i = 0; i < 3; i++) {
      final fall = (progress * 1.5 + i * 0.33) % 1.0;
      final x = c.dx - r * 0.2 + i * r * 0.2;
      final y = c.dy + r * 0.3 + fall * r * 0.5;
      canvas.drawCircle(
        Offset(x, y),
        r * 0.06,
        Paint()..color = secondary.withValues(alpha: 1 - fall),
      );
    }
  }

  void _drawRadar(
      Canvas canvas, Offset c, double r, Paint p, Paint pFill) {
    
    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(c, r * 0.3 * i,
          Paint()
            ..color = primary.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.05);
    }
    
    final sweep = progress * 2 * pi;
    final shader = SweepGradient(
      startAngle: 0,
      endAngle: pi / 2,
      colors: [
        primary.withValues(alpha: 0.0),
        primary.withValues(alpha: 0.4),
      ],
      transform: GradientRotation(sweep - pi / 2),
    ).createShader(Rect.fromCircle(center: c, radius: r * 0.9));
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.9),
      0,
      pi / 2,
      true,
      Paint()..shader = shader,
    );
    
    final blips = [
      (0.3, 0.4, 0.7),
      (0.6, 0.7, 0.3),
      (0.8, 0.5, 0.9),
    ];
    for (final b in blips) {
      final blipProgress = (progress * 2 - b.$3) % 1.0;
      if (blipProgress > 0 && blipProgress < 0.2) {
        final x = c.dx + cos(b.$1 * 2 * pi) * r * 0.7 * b.$2;
        final y = c.dy + sin(b.$1 * 2 * pi) * r * 0.7 * b.$2;
        canvas.drawCircle(
          Offset(x, y),
          r * 0.1,
          Paint()..color = primary,
        );
      }
    }
  }

  void _drawChat(
      Canvas canvas, Offset c, double r, Paint p, Paint pFill) {
    
    final scale = 1.0 + 0.12 * sin(progress * 2 * pi);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(scale);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: r * 1.1,
      height: r * 0.9,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(r * 0.25)),
      pFill,
    );
    
    final tail = Path()
      ..moveTo(-r * 0.2, r * 0.4)
      ..lineTo(-r * 0.05, r * 0.4)
      ..lineTo(-r * 0.2, r * 0.6)
      ..close();
    canvas.drawPath(tail, pFill);
    
    for (var i = 0; i < 3; i++) {
      final dx = (i - 1) * r * 0.2;
      final dotPhase = (progress * 3 - i * 0.3) % 1.0;
      final dy = sin(dotPhase * pi) * -r * 0.08;
      canvas.drawCircle(
        Offset(dx, dy),
        r * 0.08,
        Paint()..color = Colors.white,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LottiePainter old) =>
      old.progress != progress || old.type != type;
}
