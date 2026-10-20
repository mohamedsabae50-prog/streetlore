import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/compass_service.dart';
import '../../core/services/qibla_service.dart';

class CompassCard extends StatefulWidget {
  const CompassCard({super.key});

  @override
  State<CompassCard> createState() => _CompassCardState();
}

class _CompassCardState extends State<CompassCard>
    with TickerProviderStateMixin {
  late final AnimationController _introCtrl;
  late final Animation<double> _introScale;
  late final Animation<double> _introOffset;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  late final AnimationController _iconCtrl;
  late final Animation<double> _iconRotation;

  double _qiblaBearingDeg = 0;
  double _currentHeadingDeg = 0;
  bool _qiblaAvailable = false;
  bool _wasQiblaAligned = false;

  StreamSubscription<double>? _compassSub;
  StreamSubscription<double>? _qiblaSub;

  @override
  void initState() {
    super.initState();
    _introCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..forward();
    _introScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.65, end: 1.1), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 45),
    ]).animate(CurvedAnimation(parent: _introCtrl, curve: Curves.easeOut));

    _introOffset = Tween<double>(
      begin: 26,
      end: 0,
    ).animate(CurvedAnimation(parent: _introCtrl, curve: Curves.easeOutQuint));

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _pulse = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _iconCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _iconRotation = Tween<double>(
      begin: 0.0,
      end: 2 * pi,
    ).animate(CurvedAnimation(parent: _iconCtrl, curve: Curves.linear));

    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) _pulseCtrl.repeat(reverse: true);
    });

    CompassService.instance.start();
    _compassSub = CompassService.instance.headingStream.listen((deg) {
      if (!mounted) return;
      _currentHeadingDeg = deg;
      _checkQiblaAlignment();
      final working = CompassService.instance.isActuallyWorking;
      final iconShouldSpin = !working && !_iconCtrl.isAnimating;
      final iconShouldStop = working && _iconCtrl.isAnimating;

      // Do NOT call setState() for heading updates!
      if (iconShouldSpin) {
        _iconCtrl.repeat();
      } else if (iconShouldStop) {
        _iconCtrl.stop();
        _iconCtrl.value = 0;
      }
    });

    _qiblaSub = QiblaService.instance.bearingStream.listen((bearing) {
      if (!mounted) return;
      setState(() {
        _qiblaBearingDeg = bearing;
        _qiblaAvailable = true;
      });
      _checkQiblaAlignment();
    });

    // Kick off location fetch (cached if location already known).
    QiblaService.instance.refreshFromCurrentLocation().then((_) {
      if (!mounted) return;
      setState(() {
        _qiblaAvailable = QiblaService.instance.hasBearing;
        _qiblaBearingDeg = QiblaService.instance.lastBearingDeg;
      });
    });
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    _qiblaSub?.cancel();
    _introCtrl.dispose();
    _pulseCtrl.dispose();
    _iconCtrl.dispose();
    super.dispose();
  }

  String _dirLabel(double deg) {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final i = ((deg % 360) / 45).round() % 8;
    return dirs[i];
  }

  bool get _isQiblaAligned {
    final difference = (_qiblaBearingDeg - _currentHeadingDeg) % 360;
    final normalizedDifference = (difference + 360) % 360;
    final shortestDifference = normalizedDifference > 180
        ? normalizedDifference - 360
        : normalizedDifference;
    return _qiblaAvailable && shortestDifference.abs() <= 5;
  }

  void _checkQiblaAlignment() {
    final aligned = _isQiblaAligned;
    final alignmentChanged = aligned != _wasQiblaAligned;
    if (aligned && !_wasQiblaAligned) {
      HapticFeedback.mediumImpact();
    }
    _wasQiblaAligned = aligned;
    if (alignmentChanged && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: AnimatedBuilder(
        animation: Listenable.merge([_introCtrl, _pulseCtrl]),
        builder: (context, _) {
          final pulseValue = _pulse.value;
          final pulseScale = 1.0 + pulseValue * 0.03;
          final glowAlpha = (pulseValue * 32).clamp(0, 32).toInt();

          return Transform.translate(
            offset: Offset(0, _introOffset.value),
            child: Transform.scale(
              scale: _introScale.value * pulseScale,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: _isQiblaAligned
                        ? const Color(0xFF22C55E)
                        : _qiblaAvailable
                        ? const Color(0xFFEAB308).withValues(alpha: 0.65)
                        : context.textSec.withValues(alpha: 0.1),
                    width: _isQiblaAligned ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 84,
                      height: 84,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4F46E5), Color(0xFF22C55E)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Color.fromARGB(glowAlpha, 79, 70, 229),
                                  blurRadius: 16 + pulseValue * 8,
                                  spreadRadius: pulseValue * 2,
                                ),
                              ],
                            ),
                          ),
                          StreamBuilder<double>(
                            stream: CompassService.instance.headingStream,
                            builder: (context, snapshot) {
                              final heading =
                                  snapshot.data ?? _currentHeadingDeg;
                              return CompassDialIndicators(
                                headingDegrees: heading,
                                qiblaBearingDegrees: _qiblaBearingDeg,
                                qiblaAvailable: _qiblaAvailable,
                                qiblaAligned: _isQiblaAligned,
                              );
                            },
                          ),
                          AnimatedBuilder(
                            animation: _iconCtrl,
                            builder: (context, _) {
                              return StreamBuilder<double>(
                                stream: CompassService.instance.headingStream,
                                builder: (context, snapshot) {
                                  final heading =
                                      snapshot.data ?? _currentHeadingDeg;
                                  final hasCompass =
                                      CompassService.instance.isActuallyWorking;
                                  final arrowAngle = hasCompass
                                      ? (_qiblaAvailable
                                                ? _qiblaBearingDeg - heading
                                                : -heading) *
                                            (pi / 180.0)
                                      : _iconRotation.value;
                                  return Transform.rotate(
                                    angle: arrowAngle,
                                    child: Icon(
                                      Icons.navigation_rounded,
                                      color: _isQiblaAligned
                                          ? const Color(0xFF22C55E)
                                          : Colors.white,
                                      size: 30,
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Compass',
                                style: TextStyle(
                                  color: context.textPri,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              StreamBuilder<double>(
                                stream: CompassService.instance.headingStream,
                                builder: (context, snapshot) {
                                  final heading = snapshot.data ?? 0.0;
                                  final hasCompass =
                                      CompassService.instance.isActuallyWorking;
                                  if (!hasCompass) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF22C55E,
                                        ).withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _dirLabel(heading),
                                        style: const TextStyle(
                                          color: Color(0xFF22C55E),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          StreamBuilder<double>(
                            stream: CompassService.instance.headingStream,
                            builder: (context, snapshot) {
                              final heading = snapshot.data ?? 0.0;
                              final hasCompass =
                                  CompassService.instance.isActuallyWorking;
                              return Text(
                                hasCompass
                                    ? '${heading.round()}° · Heading'
                                    : 'Calibrating…',
                                style: TextStyle(
                                  color: context.textSec,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              );
                            },
                          ),
                          if (_qiblaAvailable) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.mosque_rounded,
                                  color: Color(0xFFEAB308),
                                  size: 13,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Qibla ${_qiblaBearingDeg.round()}°',
                                  style: TextStyle(
                                    color: context.textSec,
                                    fontSize: 11,
                                    height: 1.3,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class CompassDialIndicators extends StatelessWidget {
  const CompassDialIndicators({
    super.key,
    required this.headingDegrees,
    required this.qiblaBearingDegrees,
    required this.qiblaAvailable,
    this.qiblaAligned = false,
  });

  final double headingDegrees;
  final double qiblaBearingDegrees;
  final bool qiblaAvailable;
  final bool qiblaAligned;

  @override
  Widget build(BuildContext context) {
    const size = 84.0;
    const markerSize = 18.0;
    const radius = 31.0;
    final bearing = qiblaBearingDegrees * pi / 180;
    final qiblaLeft = size / 2 + radius * sin(bearing) - markerSize / 2;
    final qiblaTop = size / 2 - radius * cos(bearing) - markerSize / 2;

    return Transform.rotate(
      angle: -headingDegrees * pi / 180,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Positioned(
              top: 3,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'N',
                  key: ValueKey('compass-north-marker'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            if (qiblaAvailable)
              Positioned(
                left: qiblaLeft,
                top: qiblaTop,
                child: Container(
                  key: const ValueKey('compass-qibla-marker'),
                  width: markerSize,
                  height: markerSize,
                  decoration: BoxDecoration(
                    color: qiblaAligned
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFEAB308),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEAB308).withValues(alpha: 0.8),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.mosque_rounded,
                    color: Colors.white,
                    size: 11,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
