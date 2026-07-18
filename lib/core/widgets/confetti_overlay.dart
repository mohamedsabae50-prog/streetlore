import 'dart:math';
import 'package:flutter/material.dart';

class ConfettiOverlay extends StatefulWidget {
  final ConfettiController controller;
  final int particleCount;
  final Duration duration;
  final List<Color>? colors;

  const ConfettiOverlay({
    super.key,
    required this.controller,
    this.particleCount = 80,
    this.duration = const Duration(milliseconds: 2200),
    this.colors,
  });

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class ConfettiController {
  _ConfettiOverlayState? _state;
  void _attach(_ConfettiOverlayState s) => _state = s;
  void _detach(_ConfettiOverlayState s) {
    if (identical(_state, s)) _state = null;
  }

  void play() => _state?._fire();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final List<_Confetto> _confetti = [];
  final Random _rng = Random();
  late final List<Color> _palette;

  @override
  void initState() {
    super.initState();
    widget.controller._attach(this);
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _palette = widget.colors ??
        const [
          Color(0xFFE11D48),
          Color(0xFFF59E0B),
          Color(0xFF10B981),
          Color(0xFF3B82F6),
          Color(0xFF8B5CF6),
          Color(0xFFEC4899),
          Color(0xFF14B8A6),
        ];
  }

  @override
  void dispose() {
    widget.controller._detach(this);
    _ctrl.dispose();
    super.dispose();
  }

  void _fire() {
    _confetti.clear();
    for (var i = 0; i < widget.particleCount; i++) {
      _confetti.add(_Confetto.random(_rng, _palette));
    }
    _ctrl
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          if (_confetti.isEmpty) return const SizedBox.shrink();
          return CustomPaint(
            painter: _ConfettiPainter(
              confetti: _confetti,
              progress: _ctrl.value,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _Confetto {
  final double startX; 
  final double velocityX; 
  final double velocityY; 
  final double gravity; 
  final double rotationSpeed;
  final double initialRotation;
  final double size; 
  final Color color;
  final bool isCircle;
  final double phaseOffset;

  _Confetto({
    required this.startX,
    required this.velocityX,
    required this.velocityY,
    required this.gravity,
    required this.rotationSpeed,
    required this.initialRotation,
    required this.size,
    required this.color,
    required this.isCircle,
    required this.phaseOffset,
  });

  factory _Confetto.random(Random rng, List<Color> palette) {
    return _Confetto(
      startX: 0.2 + rng.nextDouble() * 0.6, 
      velocityX: (rng.nextDouble() - 0.5) * 1.4,
      velocityY: -(1.5 + rng.nextDouble() * 1.5), 
      gravity: 1.6 + rng.nextDouble() * 0.6,
      rotationSpeed: (rng.nextDouble() - 0.5) * 8,
      initialRotation: rng.nextDouble() * pi * 2,
      size: 6 + rng.nextDouble() * 8,
      color: palette[rng.nextInt(palette.length)],
      isCircle: rng.nextDouble() < 0.4,
      phaseOffset: rng.nextDouble() * 0.15,
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_Confetto> confetti;
  final double progress;
  _ConfettiPainter({required this.confetti, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final c in confetti) {
      final p = (progress - c.phaseOffset).clamp(0.0, 1.0);
      if (p <= 0) continue;
      final t = p * 2.4; 

      
      final x = (c.startX + c.velocityX * t * 0.18) * size.width;
      final y = size.height * 0.18 +
          (c.velocityY * t + 0.5 * c.gravity * t * t) * size.height * 0.18;

      
      final opacity = (1 - p).clamp(0.0, 1.0);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(c.initialRotation + c.rotationSpeed * t);
      final paint = Paint()..color = c.color.withValues(alpha: opacity);
      if (c.isCircle) {
        canvas.drawCircle(Offset.zero, c.size / 2, paint);
      } else {
        final rect = Rect.fromCenter(
          center: Offset.zero,
          width: c.size,
          height: c.size * 0.5,
        );
        canvas.drawRect(rect, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) =>
      old.progress != progress || old.confetti != confetti;
}
