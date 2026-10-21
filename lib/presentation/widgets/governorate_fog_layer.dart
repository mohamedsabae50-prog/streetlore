import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:provider/provider.dart';

import '../../data/models/egypt_governorate.dart';
import '../../data/models/place_model.dart';
import '../../logic/governorate_provider.dart';
import 'governorate_explorer_sheet.dart';

@visibleForTesting
Path buildGovernorateFogCutoutPath(Size size, List<Offset> boundaryPoints) {
  return Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(Rect.fromLTWH(-200, -200, size.width + 400, size.height + 400))
    ..addPath(_buildSmoothPolygonPath(boundaryPoints), Offset.zero);
}

@visibleForTesting
Path buildSmoothGovernoratePath(List<Offset> points) =>
    _buildSmoothPolygonPath(points);

Path _buildSmoothPolygonPath(List<Offset> points) {
  if (points.length < 3) return Path();

  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (var i = 0; i < points.length; i++) {
    final current = points[i];
    final next = points[(i + 1) % points.length];
    final previous = points[(i - 1 + points.length) % points.length];
    final afterNext = points[(i + 2) % points.length];
    final control1 = current + (next - previous) / 6;
    final control2 = next - (afterNext - current) / 6;
    path.cubicTo(
      control1.dx,
      control1.dy,
      control2.dx,
      control2.dy,
      next.dx,
      next.dy,
    );
  }
  return path..close();
}

class GovernorateFogLayer extends StatelessWidget {
  const GovernorateFogLayer({
    super.key,
    required this.places,
    this.visitedPlaceIds = const {},
  });

  final List<PlaceModel> places;
  final Set<String> visitedPlaceIds;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GovernorateProvider>();
    final camera = MapCamera.of(context);
    final active =
        EgyptGovernorate.byId[provider.activeGovernorate] ??
        EgyptGovernorate.byId['alexandria']!;
    final fogged = EgyptGovernorate.all
        .where((item) => item.id != active.id)
        .toList(growable: false);
    final boundaryPoints = active.boundaryPolygon
        .map((point) {
          final screenPoint = camera.latLngToScreenPoint(point);
          return Offset(screenPoint.x, screenPoint.y);
        })
        .toList(growable: false);
    final activeBounds = _boundsOf(boundaryPoints);
    final visibleBadges = filterGovernorateBadges(
      candidates: fogged,
      camera: camera,
      activeBounds: activeBounds,
    );
    final territoryBoundaries = fogged
        .map(
          (governorate) => governorate.boundaryPolygon
              .map((point) {
                final screenPoint = camera.latLngToScreenPoint(point);
                return Offset(screenPoint.x, screenPoint.y);
              })
              .toList(growable: false),
        )
        .toList(growable: false);

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              key: const ValueKey('governorate-cloud-fog'),
              painter: _BumpCloudFogPainter(
                camera: camera,
                boundaryPoints: boundaryPoints,
                territoryBoundaries: territoryBoundaries,
                fogEnabled: provider.fogEnabled,
              ),
            ),
          ),
        ),
        if (provider.fogEnabled)
          MarkerLayer(
            markers: [
              for (final item in visibleBadges)
                Marker(
                  point: LatLng(item.centerLat, item.centerLng),
                  width: 96,
                  height: 32,
                  child: _FogBadge(
                    governorate: item,
                    count: places
                        .where((place) => place.governorate == item.id)
                        .length,
                    onTap: () => showGovernorateExplorerSheet(
                      context,
                      places: places,
                      visitedPlaceIds: visitedPlaceIds,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

@visibleForTesting
List<EgyptGovernorate> filterGovernorateBadges({
  required List<EgyptGovernorate> candidates,
  required MapCamera camera,
  required Rect activeBounds,
}) {
  final accepted = <EgyptGovernorate>[];
  final occupied = <Rect>[];
  for (final governorate in candidates) {
    final projected = camera.latLngToScreenPoint(
      LatLng(governorate.centerLat, governorate.centerLng),
    );
    final center = Offset(projected.x, projected.y);
    final nearestX = center.dx.clamp(activeBounds.left, activeBounds.right);
    final nearestY = center.dy.clamp(activeBounds.top, activeBounds.bottom);
    if ((center - Offset(nearestX, nearestY)).distance <= 64) continue;

    final bounds = Rect.fromCenter(center: center, width: 96, height: 32);
    if (occupied.any((existing) => bounds.inflate(10).overlaps(existing))) {
      continue;
    }
    accepted.add(governorate);
    occupied.add(bounds);
  }
  return accepted;
}

Rect _boundsOf(List<Offset> points) {
  var left = double.infinity;
  var top = double.infinity;
  var right = double.negativeInfinity;
  var bottom = double.negativeInfinity;
  for (final point in points) {
    left = math.min(left, point.dx);
    top = math.min(top, point.dy);
    right = math.max(right, point.dx);
    bottom = math.max(bottom, point.dy);
  }
  return Rect.fromLTRB(left, top, right, bottom);
}

class _BumpCloudFogPainter extends CustomPainter {
  const _BumpCloudFogPainter({
    required this.camera,
    required this.boundaryPoints,
    required this.territoryBoundaries,
    required this.fogEnabled,
  });

  final MapCamera camera;
  final List<Offset> boundaryPoints;
  final List<List<Offset>> territoryBoundaries;
  final bool fogEnabled;

  @override
  void paint(Canvas canvas, Size size) {
    if (boundaryPoints.length < 3) return;

    final boundaryPath = _buildSmoothPolygonPath(boundaryPoints);
    if (fogEnabled) {
      final cutoutPath = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(
          Rect.fromLTWH(-200, -200, size.width + 400, size.height + 400),
        )
        ..addPath(boundaryPath, Offset.zero);
      canvas.drawPath(
        cutoutPath,
        Paint()
          ..color = const Color(0xF4070B14)
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );

      canvas.save();
      canvas.clipPath(cutoutPath);
      for (final points in territoryBoundaries) {
        if (points.length < 3) continue;
        canvas.drawPath(
          _buildSmoothPolygonPath(points),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1
            ..color = const Color(0x2600E5FF)
            ..isAntiAlias = true,
        );
      }
      _drawCloudCanopy(canvas, size);
      _drawCloudBank(canvas, boundaryPath, size);
      canvas.restore();
    }
  }

  void _drawCloudCanopy(Canvas canvas, Size size) {
    final extent = Rect.fromLTWH(
      -240,
      -240,
      size.width + 480,
      size.height + 480,
    );
    final cloudMasses = Path();
    _appendCloudMasses(
      cloudMasses,
      extent,
      spacing: 48,
      minRadius: 112,
      maxRadius: 148,
      seed: 17,
    );
    _appendCloudMasses(
      cloudMasses,
      extent,
      spacing: 80,
      minRadius: 184,
      maxRadius: 238,
      seed: 43,
    );
    for (final (color, sigma) in const [
      (Color(0x38182338), 55.0),
      (Color(0x2E0F1726), 42.0),
      (Color(0x24243450), 30.0),
    ]) {
      canvas.drawPath(
        cloudMasses,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma)
          ..isAntiAlias = true,
      );
    }
  }

  void _appendCloudMasses(
    Path destination,
    Rect extent, {
    required double spacing,
    required double minRadius,
    required double maxRadius,
    required int seed,
  }) {
    final columns = (extent.width / spacing).ceil();
    final rows = (extent.height / spacing).ceil();
    for (var row = 0; row <= rows; row++) {
      for (var column = 0; column <= columns; column++) {
        final x = extent.left + column * spacing;
        final y = extent.top + row * spacing;
        final noiseX = _fbmNoise(column * 0.31 + seed, row * 0.31);
        final noiseY = _fbmNoise(column * 0.31, row * 0.31 + seed);
        final center = Offset(
          x + (noiseX - 0.5) * spacing * 0.86,
          y + (noiseY - 0.5) * spacing * 0.86,
        );
        final radiusNoise = _fbmNoise(column * 0.17 + seed, row * 0.17 + 9);
        final radius = minRadius + (maxRadius - minRadius) * radiusNoise;
        destination.addPath(
          _buildCloudBlob(center, radius, seed + row * columns + column),
          Offset.zero,
        );
      }
    }
  }

  void _drawCloudBank(Canvas canvas, Path boundaryPath, Size size) {
    const strokes = [
      (90.0, Color(0xF5060911), 34.0),
      (65.0, Color(0xD90A101D), 28.0),
      (44.0, Color(0xAA111A2E), 22.0),
      (26.0, Color(0x661A2740), 16.0),
      (14.0, Color(0x331A2740), 11.0),
    ];
    for (final (width, color, sigma) in strokes) {
      canvas.drawPath(
        boundaryPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma)
          ..isAntiAlias = true,
      );
    }

    final bankLobes = Path();
    final metrics = boundaryPath.computeMetrics().toList(growable: false);
    var lobeIndex = 0;
    for (final metric in metrics) {
      for (var distance = 0.0; distance < metric.length; distance += 18) {
        final tangent = metric.getTangentForOffset(distance);
        if (tangent == null ||
            !Rect.fromLTWH(
              -80,
              -80,
              size.width + 160,
              size.height + 160,
            ).contains(tangent.position)) {
          continue;
        }
        final noise = _fbmNoise(lobeIndex * 0.73, 5.1);
        final radius = 36 + noise * 32;
        bankLobes.addPath(
          _buildCloudBlob(tangent.position, radius, lobeIndex + 701),
          Offset.zero,
        );
        lobeIndex++;
      }
    }
    canvas.drawPath(
      bankLobes,
      Paint()
        ..color = const Color(0xC90A101D)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24)
        ..isAntiAlias = true,
    );
  }

  Path _buildCloudBlob(Offset center, double radius, int seed) {
    final points = <Offset>[];
    const pointCount = 12;
    for (var index = 0; index < pointCount; index++) {
      final angle = 2 * math.pi * index / pointCount;
      final nx = math.cos(angle);
      final ny = math.sin(angle);
      final shapeNoise = _fbmNoise(nx * 2.3 + seed, ny * 2.3 + seed * 0.37);
      final fineNoise = _valueNoise(nx * 5.1 + seed * 0.11, ny * 5.1);
      final variedRadius =
          radius * (0.78 + shapeNoise * 0.34 + (fineNoise - 0.5) * 0.16);
      points.add(
        Offset(
          center.dx + nx * variedRadius,
          center.dy +
              ny *
                  variedRadius *
                  (0.78 + _valueNoise(seed.toDouble(), 3.0) * 0.32),
        ),
      );
    }
    return _buildSmoothPolygonPath(points);
  }

  double _fbmNoise(double x, double y) {
    var value = 0.0;
    var amplitude = 0.5;
    var amplitudeSum = 0.0;
    for (var octave = 0; octave < 4; octave++) {
      value += _valueNoise(x, y) * amplitude;
      amplitudeSum += amplitude;
      x *= 2.03;
      y *= 2.03;
      amplitude *= 0.5;
    }
    return value / amplitudeSum;
  }

  double _valueNoise(double x, double y) {
    final x0 = x.floor();
    final y0 = y.floor();
    final tx = x - x0;
    final ty = y - y0;
    final sx = tx * tx * (3 - 2 * tx);
    final sy = ty * ty * (3 - 2 * ty);
    final top = _lerp(_noiseValue(x0, y0), _noiseValue(x0 + 1, y0), sx);
    final bottom = _lerp(
      _noiseValue(x0, y0 + 1),
      _noiseValue(x0 + 1, y0 + 1),
      sx,
    );
    return _lerp(top, bottom, sy);
  }

  double _noiseValue(int x, int y) {
    var hash = x * 374761393 + y * 668265263 + 0x1b873593;
    hash = (hash ^ (hash >> 13)) * 1274126177;
    hash ^= hash >> 16;
    return (hash & 0x7fffffff) / 0x7fffffff;
  }

  @override
  bool shouldRepaint(covariant _BumpCloudFogPainter oldDelegate) =>
      oldDelegate.camera != camera ||
      oldDelegate.boundaryPoints != boundaryPoints ||
      oldDelegate.territoryBoundaries != territoryBoundaries ||
      oldDelegate.fogEnabled != fogEnabled;
}

double _lerp(double start, double end, double t) => start + (end - start) * t;

class _FogBadge extends StatelessWidget {
  const _FogBadge({
    required this.governorate,
    required this.count,
    required this.onTap,
  });

  final EgyptGovernorate governorate;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return GestureDetector(
      onTap: onTap,
      child: Align(
        widthFactor: 1,
        heightFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xE6162433),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.55),
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x4400E5FF), blurRadius: 9),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (count == 0)
                  const Text('🔒', style: TextStyle(fontSize: 11)),
                if (count > 0)
                  const Icon(
                    Icons.place_rounded,
                    size: 13,
                    color: Color(0xFF55E6C1),
                  ),
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 58),
                  child: Text(
                    count > 0
                        ? '$count'
                        : isArabic
                        ? governorate.nameAr
                        : governorate.nameEn,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
