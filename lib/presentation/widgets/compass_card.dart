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

  double _headingDeg = 0;
  // v1.0.80 — heading is a ValueNotifier so the compass stream can
  // drive the inner arrow's Transform.rotate without triggering a
  // rebuild of the whole card. The text labels and Qibla indicator
  // only rebuild when those values actually change.
  final ValueNotifier<double> _headingNotifier = ValueNotifier<double>(0);
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
    )..forward();
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
      // Push the new heading into the notifier. This rebuilds ONLY
      // the inner icon (via ValueListenableBuilder below), not the
      // whole compass card.
      _headingNotifier.value = deg;
      // Keep _headingDeg in sync for the "Heading · °°" text label.
      // setState is gated to working-state transitions only — so the
      // whole card doesn't rebuild on every compass tick.
      final prevWorking = _lastWorking;
      _lastWorking = working;
      _headingDeg = deg;
      if (prevWorking != working) {
        setState(() {});
      }
      // Manage the intro-loop animation only on transitions.
      final iconShouldSpin = !working && !_iconCtrl.isAnimating;
      final iconShouldStop = working && _iconCtrl.isAnimating;
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
    _headingNotifier.dispose();
    super.dispose();
  }

  String _dirLabel(double deg) {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final i = ((deg % 360) / 45).round() % 8;
    return dirs[i];
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
          final hasCompass = CompassService.instance.isActuallyWorking;
          final dir = _dirLabel(_headingDeg);
          // v1.0.80 — Qibla arrow uses a city-center fallback so the
          // indicator is visible even before location permission is
          // granted.
          final qiblaBearingForArrow = _qiblaAvailable
              ? _qiblaBearingDeg
              : _kDefaultQiblaBearingDeg;
          final qiblaRelDeg = qiblaBearingForArrow - _headingDeg;
          return Transform.translate(
            offset: Offset(0, _introOffset.value),
            child: Transform.rotate(
              angle: _introRotation.value,
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
                            // v1.0.80 — Static outer disc (gradient +
                            // N label + boxShadow stay still). Only
                            // the inner arrow icon rotates.
                            Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4F46E5),
                                    Color(0xFF22C55E)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color.fromARGB(
                                        glowAlpha, 79, 70, 229),
                                    blurRadius: 16 + pulseValue * 8,
                                    spreadRadius: pulseValue * 2,
                                  ),
                                ],
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  const Positioned(
                                    top: 4,
                                    child: Text(
                                      'N',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  // Only the arrow icon inside
                                  // rotates. v1.0.80 — this
                                  // ValueListenableBuilder means a
                                  // heading change rebuilds just
                                  // this 30-px Icon, not the whole
                                  // compass row.
                                  ValueListenableBuilder<double>(
                                    valueListenable: _headingNotifier,
                                    builder: (context, hdg, _) {
                                      final angle = hasCompass
                                          ? -hdg * (pi / 180.0)
                                          : _iconRotation.value;
                                      return Transform.rotate(
                                        angle: angle,
                                        child: const Icon(
                                          Icons.navigation_rounded,
                                          color: Colors.white,
                                          size: 30,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            // v1.0.80 — Qibla arrow is now always
                            // shown (falls back to city-center
                            // bearing if GPS isn't ready yet).
                            Transform.rotate(
                              angle: qiblaRelDeg * (pi / 180.0),
                              child: Container(
                                width: 84,
                                height: 84,
                                alignment: Alignment.topCenter,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 1),
                                  child: Container(
                                    width: 14,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEAB308),
                                      borderRadius:
                                          BorderRadius.circular(3),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFEAB308)
                                              .withValues(alpha: 0.8),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.mosque_rounded,
                                        color: Colors.white,
                                        size: 11,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
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
                                      dir,
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
                            // v1.0.80 — always show Qibla row.
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
          );
        },
      ),
    );
  }
}