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
/// row in the labels below stays visible (and roughly accurate)
/// before GPS is ready, with an "(approx)" tag in the subtitle.
const double _kDefaultQiblaBearingDeg = 135.0;

class CompassCard extends StatefulWidget {
  const CompassCard({super.key});

  @override
  State<CompassCard> createState() => _CompassCardState();
}

class _CompassCardState extends State<CompassCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinCtrl;

  /// Latest heading from the compass sensor. Fed directly into the
  /// Transform.rotate with NO interpolation — the device sensor is
  /// already 60Hz, and any tweening fights the stream and drops frames.
  double _headingDeg = 0.0;
  double _qiblaBearingDeg = _kDefaultQiblaBearingDeg;
  bool _qiblaAvailable = false;
  bool _compassWorking = false;

  StreamSubscription<double>? _compassSub;
  StreamSubscription<double>? _qiblaSub;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    CompassService.instance.start();
    _compassSub = CompassService.instance.headingStream.listen((deg) {
      if (!mounted) return;
      // v1.0.85 — NaN guard. Android compass sensors occasionally
      // emit NaN during the first ~200ms of calibration.
      final safeDeg = deg.isFinite ? deg : 0.0;
      setState(() {
        _headingDeg = safeDeg;
        _compassWorking = CompassService.instance.isActuallyWorking;
      });
      if (_compassWorking && _spinCtrl.isAnimating) {
        _spinCtrl.stop();
        _spinCtrl.value = 0;
      } else if (!_compassWorking && !_spinCtrl.isAnimating) {
        _spinCtrl.repeat();
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
    _spinCtrl.dispose();
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                    ),
                    child: const Center(
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
                  const Positioned(
                    bottom: 4,
                    left: 0,
                    right: 0,
                    child: Center(child: _QiblaBox()),
                  ),
                  // v1.0.85 — ONLY the inner arrow rotates. The
                  // heading value comes straight from the device
                  // sensor (60Hz) with NO TweenAnimationBuilder — the
                  // previous 80ms tween added input lag.
                  _compassWorking
                          ? Transform.rotate(
                              angle: -_headingDeg * (pi / 180.0),
                              child: const Icon(
                                Icons.navigation_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            )
                          : AnimatedBuilder(
                              animation: _spinCtrl,
                              builder: (context, _) => Transform.rotate(
                                angle: _spinCtrl.value * 2 * pi,
                                child: const Icon(
                                  Icons.navigation_rounded,
                                  color: Colors.white,
                                  size: 30,
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
                      if (_compassWorking) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E)
                                .withValues(alpha: 0.18),
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
                    _compassWorking
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
    );
  }
}

class _QiblaBox extends StatelessWidget {
  const _QiblaBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 22,
      decoration: BoxDecoration(
        color: const Color(0xFFEAB308),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEAB308).withValues(alpha: 0.85),
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
    );
  }
}