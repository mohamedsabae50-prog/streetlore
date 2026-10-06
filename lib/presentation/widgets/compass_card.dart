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

/// v1.0.86 — Top-level card. Holds NO compass heading state — the
/// compass subscription lives entirely inside [_CompassArrow], so
/// this widget only rebuilds when the Qibla service flips state.
class CompassCard extends StatefulWidget {
  const CompassCard({super.key});

  @override
  State<CompassCard> createState() => _CompassCardState();
}

class _CompassCardState extends State<CompassCard> {
  double _qiblaBearingDeg = _kDefaultQiblaBearingDeg;
  bool _qiblaAvailable = false;
  StreamSubscription<double>? _qiblaSub;

  @override
  void initState() {
    super.initState();
    CompassService.instance.start();

    _qiblaSub = QiblaService.instance.bearingStream.listen((bearing) {
      if (!mounted) return;
      final safeBearing =
          bearing.isFinite ? bearing : _kDefaultQiblaBearingDeg;
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
    _qiblaSub?.cancel();
    super.dispose();
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
                  const _CompassArrow(),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Compass',
                    style: TextStyle(
                      color: context.textPri,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    !_qiblaAvailable
                        ? 'Qibla ${_kDefaultQiblaBearingDeg.round()}° (approx)'
                        : 'Qibla ${_qiblaBearingDeg.round()}°',
                    style: TextStyle(
                      color: context.textSec,
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
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

/// v1.0.86 — Isolated compass arrow. Owns its own StreamBuilder that
/// listens to [CompassService.instance.headingStream]. Only THIS
/// subtree responds to stream emissions; the outer [_CompassCardState],
/// the background gradient, and the Qibla box NEVER rebuild when the
/// sensor emits.
class _CompassArrow extends StatefulWidget {
  const _CompassArrow();

  @override
  State<_CompassArrow> createState() => _CompassArrowState();
}

class _CompassArrowState extends State<_CompassArrow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinCtrl;
  StreamSubscription<double>? _sub;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    if (!CompassService.instance.isActuallyWorking) {
      _spinCtrl.repeat();
    }
    _sub = CompassService.instance.headingStream.listen(_onHeading);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _spinCtrl.dispose();
    super.dispose();
  }

  void _onHeading(double deg) {
    if (!mounted) return;
    final working = CompassService.instance.isActuallyWorking;
    if (working && _spinCtrl.isAnimating) {
      _spinCtrl.stop();
      _spinCtrl.value = 0;
    } else if (!working && !_spinCtrl.isAnimating) {
      _spinCtrl.repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: CompassService.instance.headingStream,
      builder: (context, snapshot) {
        if (!CompassService.instance.isActuallyWorking) {
          return AnimatedBuilder(
            animation: _spinCtrl,
            builder: (_, _) => Transform.rotate(
              angle: _spinCtrl.value * 2 * pi,
              child: const Icon(
                Icons.navigation_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          );
        }
        final raw = snapshot.data ?? 0.0;
        final safeDeg = raw.isFinite ? raw : 0.0;
        return Transform.rotate(
          angle: -safeDeg * (pi / 180.0),
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