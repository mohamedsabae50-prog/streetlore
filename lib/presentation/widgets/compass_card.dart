import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/compass_service.dart';
import '../../core/services/qibla_service.dart';

/// v1.0.80 — Default Qibla bearing for users who haven't granted
/// location permission. Computed from Alexandria city center
/// (31.2001 N, 29.9187 E) to Mecca (21.4225 N, 39.8262 E) via the
/// great-circle initial-bearing formula; rounds to ~135°. The Qibla
/// arrow stays visible (and roughly accurate) before GPS is ready,
/// with an "(approx)" tag in the subtitle.
const double _kDefaultQiblaBearingDeg = 135.0;

/// Smooth-interpolation duration between successive heading samples.
/// 80ms is short enough to feel instant on a phone compass (~50-60Hz
/// sensor events) and long enough that the previous frame's Transform
/// has time to settle before the next tween kicks in.
const Duration _kHeadingTweenDuration = Duration(milliseconds: 80);

class CompassCard extends StatefulWidget {
  const CompassCard({super.key});

  @override
  State<CompassCard> createState() => _CompassCardState();
}

class _CompassCardState extends State<CompassCard>
    with TickerProviderStateMixin {
  late final AnimationController _introCtrl;
  late final Animation<double> _introScale;
  late final Animation<double> _introRotation;
  late final Animation<double> _introOffset;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  late final AnimationController _iconCtrl;
  late final Animation<double> _iconRotation;

  double _headingDeg = 0.0;
  double _qiblaBearingDeg = _kDefaultQiblaBearingDeg;
  bool _qiblaAvailable = false;
  bool _lastWorking = false;

  StreamSubscription<double>? _compassSub;
  StreamSubscription<double>? _qiblaSub;

  @override
  void initState() {
    super.initState();
    _introCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _introScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.65, end: 1.1), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 45),
    ]).animate(CurvedAnimation(parent: _introCtrl, curve: Curves.easeOut));

    _introRotation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: -0.45, end: 0.35), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 0.35, end: -0.15), weight: 30),
      TweenSequenceItem(tween: Tween(begin: -0.15, end: 0.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _introCtrl, curve: Curves.easeOut));

    _introOffset = Tween<double>(
      begin: 26,
      end: 0,
    ).animate(CurvedAnimation(parent: _introCtrl, curve: Curves.easeOutQuint));

    _introCtrl.forward();

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
      final working = CompassService.instance.isActuallyWorking;
      // v1.0.82 — NaN/infinity guard. Some Android compass sensors
      // emit NaN during the first ~200ms of calibration, which used
      // to crash the TweenAnimationBuilder (sin/cos of NaN).
      final safeDeg = deg.isFinite ? deg : 0.0;
      _headingDeg = safeDeg;
      final prevWorking = _lastWorking;
      _lastWorking = working;
      if (prevWorking != working) {
        setState(() {});
      }
      if (!working && !_iconCtrl.isAnimating) {
        _iconCtrl.repeat();
      } else if (working && _iconCtrl.isAnimating) {
        _iconCtrl.stop();
        _iconCtrl.value = 0;
      }
    });

    _qiblaSub = QiblaService.instance.bearingStream.listen((bearing) {
      if (!mounted) return;
      final safeBearing = bearing.isFinite ? bearing : _kDefaultQiblaBearingDeg;
      setState(() {
        _qiblaBearingDeg = safeBearing;
        _qiblaAvailable = true;
      });
    });

    QiblaService.instance.refreshFromCurrentLocation().then((_) {
      if (!mounted) return;
      setState(() {
        _qiblaAvailable = QiblaService.instance.hasBearing;
        _qiblaBearingDeg = QiblaService.instance.lastBearingDeg.isFinite
            ? QiblaService.instance.lastBearingDeg
            : _kDefaultQiblaBearingDeg;
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

  @override
  Widget build(BuildContext context) {
    final hasCompass = CompassService.instance.isActuallyWorking;
    final qiblaBearingForArrow =
        _qiblaAvailable ? _qiblaBearingDeg : _kDefaultQiblaBearingDeg;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Transform.translate(
        offset: Offset(0, _introOffset.value),
        child: Transform.rotate(
          angle: _introRotation.value,
          child: Transform.scale(
            scale: _introScale.value,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: context.textSec.withValues(alpha: 0.1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 84,
                    height: 84,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // v1.0.82 — static gradient disc with the
                        // N label baked in. Outlined because the
                        // pulse glow sits in a SEPARATE layer on top
                        // so only the glow rebuilds on pulse ticks
                        // (the previous version wrapped the whole
                        // card in Listenable.merge which rebuilt
                        // everything at 60fps).
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF4F46E5),
                                Color(0xFF22C55E),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Stack(
                            children: [
                              Positioned(
                                top: 4,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Text(
                                    'N',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // v1.0.82 — Pulse glow isolated to its own
                        // AnimatedBuilder over BoxShadow only. The
                        // gradient disc above is NEVER rebuilt for
                        // pulse ticks anymore.
                        Positioned.fill(
                          child: IgnorePointer(
                            child: AnimatedBuilder(
                              animation: _pulseCtrl,
                              builder: (context, _) {
                                final p = _pulse.value;
                                return DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color.fromARGB(
                                          (p * 32).clamp(0, 32).toInt(),
                                          79,
                                          70,
                                          229,
                                        ),
                                        blurRadius: 16 + p * 8,
                                        spreadRadius: p * 2,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        // v1.0.82 — Heading arrow. Smoothly interpolates
                        // between successive compass sensor readings via
                        // TweenAnimationBuilder. Only this 30px Icon is
                        // rebuilt during the 80ms tween settle; the
                        // outer disc and N label are untouched.
                        _HeadingArrow(
                          working: hasCompass,
                          headingDeg: _headingDeg,
                          iconCtrl: _iconCtrl,
                          iconRotation: _iconRotation,
                        ),
                        // v1.0.82 — Qibla box. Uses the same safe
                        // layout as before (SizedBox 84x84 +
                        // Transform.rotate + Align(topCenter) +
                        // Padding). The SizedBox keeps the rotated
                        // child bounded, so the box traces the rim
                        // of the disc without escaping the 84x84
                        // bounds. TweenAnimationBuilder gives the
                        // same smooth interpolation as the heading
                        // arrow.
                        _QiblaArrow(
                          bearingDeg: qiblaBearingForArrow,
                          headingDeg: _headingDeg,
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
                            if (hasCompass) ...[
                              const SizedBox(width: 8),
                              Container(
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
                                  _dirLabel(_headingDeg),
                                  style: const TextStyle(
                                    color: Color(0xFF22C55E),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasCompass
                              ? '${_headingDeg.round()}° · Heading'
                              : 'Calibrating…',
                          style: TextStyle(
                            color: context.textSec,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
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
                              !_qiblaAvailable
                                  ? 'Qibla ${_kDefaultQiblaBearingDeg.round()}° (approx)'
                                  : 'Qibla ${_qiblaBearingDeg.round()}°',
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
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Heading arrow. Smoothly interpolates between successive compass
/// sensor readings via TweenAnimationBuilder — when a new heading
/// arrives, the previous tween's end becomes the new tween's begin
/// and the arrow glides to the new value over _kHeadingTweenDuration.
/// Only this widget rebuilds during a heading change.
class _HeadingArrow extends StatelessWidget {
  final bool working;
  final double headingDeg;
  final AnimationController iconCtrl;
  final Animation<double> iconRotation;

  const _HeadingArrow({
    required this.working,
    required this.headingDeg,
    required this.iconCtrl,
    required this.iconRotation,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: headingDeg, end: headingDeg),
      duration: _kHeadingTweenDuration,
      curve: Curves.linear,
      builder: (context, value, _) {
        final angle = working
            ? -value * (pi / 180.0)
            : iconRotation.value;
        return Transform.rotate(
          angle: angle,
          child: const Icon(
            Icons.navigation_rounded,
            color: Colors.white,
            size: 30,
          ),
        );
      },
    );
  }
}

/// Qibla direction marker. Same safe layout as v1.0.80:
/// SizedBox(84x84) bounds the rotated child so the yellow box
/// traces the rim of the disc without escaping the 84x84 square.
/// The marker rotates via Transform.rotate by the relative bearing
/// (bearingDeg - headingDeg), so it always points toward Mecca
/// relative to the phone's current heading. TweenAnimationBuilder
/// smooths the rotation as the heading stream emits new values.
class _QiblaArrow extends StatelessWidget {
  final double bearingDeg;
  final double headingDeg;

  const _QiblaArrow({
    required this.bearingDeg,
    required this.headingDeg,
  });

  @override
  Widget build(BuildContext context) {
    final relDeg = bearingDeg - headingDeg;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: relDeg, end: relDeg),
      duration: _kHeadingTweenDuration,
      curve: Curves.linear,
      builder: (context, value, _) {
        return Transform.rotate(
          angle: value * (pi / 180.0),
          child: SizedBox(
            width: 84,
            height: 84,
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Container(
                  width: 18,
                  height: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAB308),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEAB308)
                            .withValues(alpha: 0.85),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.mosque_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}