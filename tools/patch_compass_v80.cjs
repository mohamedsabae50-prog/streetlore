const fs = require('fs');

const file = 'D:/codes/streetlore/lib/presentation/widgets/compass_card.dart';
let src = fs.readFileSync(file, 'utf-8');

function replace(src, pattern, flags, label, content) {
  const re = new RegExp(pattern, flags);
  if (!re.test(src)) {
    console.error('NOT FOUND:', label);
    process.exit(1);
  }
  return src.replace(re, content);
}

// 1) Add city-center default Qibla constant just before the
//    `class CompassCard` declaration.
const classAnchor = 'class CompassCard extends StatefulWidget {';
src = replace(
  src,
  'class CompassCard extends StatefulWidget \\{',
  'g',
  'class-anchor',
  `/// v1.0.80 — Default Qibla bearing for users who haven't granted
/// location permission. Computed from Alexandria city center
/// (31.2001 N, 29.9187 E) to Mecca (21.4225 N, 39.8262 E) via the
/// great-circle initial-bearing formula; rounds to ~135°. The Qibla
/// arrow stays visible (and roughly accurate) before GPS is ready,
/// with an "(approx)" tag in the subtitle.
const double _kDefaultQiblaBearingDeg = 135.0;

class CompassCard extends StatefulWidget {`
);

// 2) Replace the field declarations: add ValueNotifier, _lastWorking,
//    default qibla initial value.
src = replace(
  src,
  /double _headingDeg = 0;\n  double _qiblaBearingDeg = 0;\n  bool _qiblaAvailable = false;\n\n  StreamSubscription<double>\? _compassSub;\n  StreamSubscription<double>\? _qiblaSub;/,
  'g',
  'state-fields',
  `double _headingDeg = 0;
  // v1.0.80 — heading is a ValueNotifier so the compass stream can
  // drive the inner arrow's Transform.rotate without triggering a
  // rebuild of the whole card. The text labels and Qibla indicator
  // only rebuild when those values actually change.
  final ValueNotifier<double> _headingNotifier = ValueNotifier<double>(0);
  double _qiblaBearingDeg = _kDefaultQiblaBearingDeg;
  bool _qiblaAvailable = false;
  bool _lastWorking = false;

  StreamSubscription<double>? _compassSub;
  StreamSubscription<double>? _qiblaSub;`
);

// 3) Replace the compass listener — push heading into the notifier
//    and only setState when the "working" state changes.
src = replace(
  src,
  /    _compassSub = CompassService\.instance\.headingStream\.listen\(\(deg\) \{\n      if \(!mounted\) return;\n      final working = CompassService\.instance\.isActuallyWorking;\n      final iconShouldSpin = !working && !_iconCtrl\.isAnimating;\n      final iconShouldStop = working && _iconCtrl\.isAnimating;\n      setState\(\(\) \{\n        _headingDeg = deg;\n        if \(iconShouldSpin\) \{\n          _iconCtrl\.repeat\(\);\n        \} else if \(iconShouldStop\) \{\n          _iconCtrl\.stop\(\);\n          _iconCtrl\.value = 0;\n        \}\n      \}\);\n    \}\);/,
  'g',
  'compass-listener',
  `    _compassSub = CompassService.instance.headingStream.listen((deg) {
      if (!mounted) return;
      final working = CompassService.instance.isActuallyWorking;
      // Push the new heading into the notifier. This rebuilds ONLY
      // the inner icon (via ValueListenableBuilder below), not the
      // whole compass card.
      _headingNotifier.value = deg;
      // Keep _headingDeg in sync for the "Heading · °°" text label.
      // setState is gated to working-state transitions only.
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
    });`
);

// 4) Update dispose to dispose the notifier.
src = replace(
  src,
  /    _compassSub\?\.cancel\(\);\n    _qiblaSub\?\.cancel\(\);\n    _introCtrl\.dispose\(\);/,
  'g',
  'dispose',
  `    _compassSub?.cancel();
    _qiblaSub?.cancel();
    _introCtrl.dispose();
    _headingNotifier.dispose();`
);

// 5) Replace the discRotation declaration block — keep dir/qiblaRelDeg
//    but drop discRotation (icon angle is now driven by the notifier).
src = replace(
  src,
  /final angle = _headingDeg \* \(pi \/ 180\.0\);\n          final dir = _dirLabel\(_headingDeg\);\n          \/\/ Rotation of the disc = -current heading \(so North stays up\n          \/\/ when the phone is pointing north\)\.\n          final discRotation = -angle;\n          \/\/ Where the Qibla arrow points INSIDE the disc\.\n          \/\/ qiblaRel = qiblaBearing - headingDeg  \(negative = to the left\)\n          final qiblaRelDeg = _qiblaAvailable\n              \? \(_qiblaBearingDeg - _headingDeg\)\n              : 0;/,
  'g',
  'rotation-block',
  `final dir = _dirLabel(_headingDeg);
          // Where the Qibla arrow points INSIDE the disc.
          // qiblaRel = qiblaBearing - headingDeg (negative = to the left).
          // Always show the Qibla arrow (v1.0.80) using a city-center
          // fallback so the indicator is visible even before location
          // permission is granted.
          final qiblaBearingForArrow = _qiblaAvailable
              ? _qiblaBearingDeg
              : _kDefaultQiblaBearingDeg;
          final qiblaRelDeg = qiblaBearingForArrow - _headingDeg;`
);

// 6) Replace the inner-icon Transform.rotate with a ValueListenableBuilder.
src = replace(
  src,
  /\/\/ Only the arrow icon inside rotates\n                                  Transform\.rotate\(\n                                    angle: hasCompass\n                                        \? discRotation\n                                        : _iconRotation\.value,\n                                    child: const Icon\(\n                                      Icons\.navigation_rounded,\n                                      color: Colors\.white,\n                                      size: 30,\n                                    \),\n                                  \),/,
  'g',
  'icon-rotate',
  `// Only the arrow icon inside rotates. v1.0.80:
                                  // ValueListenableBuilder means a heading
                                  // change rebuilds this 30-px Icon, not
                                  // the whole compass row.
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
                                  ),`
);

// 7) Remove the `if (_qiblaAvailable)` gate around the Qibla arrow
//    indicator. We now always show it, falling back to the default.
src = replace(
  src,
  /\/\/ Qibla arrow indicator \(NOT rotated with disc;\n                            \/\/ its rotation = qiblaRelDeg\)\n                            if \(_qiblaAvailable\)\n                              Transform\.rotate\(/,
  'g',
  'qibla-gate-1',
  `// Qibla arrow indicator (NOT rotated with disc; its rotation =
            // qiblaRelDeg). Always shown (v1.0.80) — falls back to
            // city-center bearing if GPS isn't ready yet.
            Transform.rotate(`
);

// 8) Remove the `if (_qiblaAvailable)` gate around the Qibla text
//    row. We now always show it, falling back to the default.
src = replace(
  src,
  /if \(_qiblaAvailable\) \.\.\.\[\n\s+const SizedBox\(height: 4\),\n\s+Row\(\n\s+children: \[\n\s+const Icon\(\n\s+Icons\.mosque_rounded,[\s\S]*?'Qibla \$\{_qiblaBearingDeg\.round\(\)\}°',/,
  'g',
  'qibla-gate-2',
  `const SizedBox(height: 4),
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
                                        ? 'Qibla \${_kDefaultQiblaBearingDeg.round()}° (approx)'
                                        : 'Qibla \${_qiblaBearingDeg.round()}°',`
);

fs.writeFileSync(file, src, 'utf-8');
console.log('Patched compass_card.dart');