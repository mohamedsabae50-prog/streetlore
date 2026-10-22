import 'dart:math' as math;
import 'dart:ui' as ui;

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
    final visibleBounds = camera.visibleBounds;
    final visibleBadges = filterGovernorateBadges(
      candidates: fogged,
      camera: camera,
      activeBounds: activeBounds,
    );
    final territoryBoundaries = fogged
        .where(
          (governorate) => _intersectsVisibleBounds(
            governorate.boundaryPolygon,
            visibleBounds,
          ),
        )
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
            child: RepaintBoundary(
              child: CustomPaint(
                key: const ValueKey('governorate-cloud-fog'),
                isComplex: true,
                willChange: false,
                painter: _BumpCloudFogPainter(
                  camera: camera,
                  boundaryPoints: boundaryPoints,
                  territoryBoundaries: territoryBoundaries,
                  fogEnabled: provider.fogEnabled,
                ),
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

bool _intersectsVisibleBounds(
  List<LatLng> polygon,
  LatLngBounds visibleBounds, {
  double padding = 0.008,
}) {
  if (polygon.isEmpty) return false;
  var south = double.infinity;
  var north = double.negativeInfinity;
  var west = double.infinity;
  var east = double.negativeInfinity;
  for (final point in polygon) {
    south = math.min(south, point.latitude);
    north = math.max(north, point.latitude);
    west = math.min(west, point.longitude);
    east = math.max(east, point.longitude);
  }
  return south <= visibleBounds.north + padding &&
      north >= visibleBounds.south - padding &&
      west <= visibleBounds.east + padding &&
      east >= visibleBounds.west - padding;
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
  static Size? _cachedHexSize;
  static ui.Path? _cachedHexPath;
  static double? _cachedHexRadius;

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
      final cutoutPath = buildGovernorateFogCutoutPath(size, boundaryPoints);

      canvas.save();
      canvas.clipPath(cutoutPath);
      canvas.drawPath(
        cutoutPath,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0x9E4A2E1B), Color(0xAD382112)],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
      canvas.drawPath(
        _hexGridPath(size),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0x26D4A373)
          ..isAntiAlias = true,
      );
      for (final points in territoryBoundaries) {
        if (points.length < 3) continue;
        canvas.drawPath(
          _buildSmoothPolygonPath(points),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = const Color(0x55E6B88A)
            ..isAntiAlias = true,
        );
      }
      canvas.restore();

      canvas.drawPath(
        boundaryPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xCC5C3A21)
          ..isAntiAlias = true,
      );
      canvas.drawPath(
        boundaryPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFFFFB74D)
          ..isAntiAlias = true,
      );
      canvas.drawPath(
        boundaryPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0x80FFF3E0)
          ..isAntiAlias = true,
      );
    }
  }

  ui.Path _hexGridPath(Size size) {
    const radius = 26.0;
    if (_cachedHexSize == size &&
        _cachedHexRadius == radius &&
        _cachedHexPath != null) {
      return _cachedHexPath!;
    }
    final horizontalSpacing = radius * 1.5;
    final verticalSpacing = radius * math.sqrt(3);
    final columns = (size.width / horizontalSpacing).ceil();
    final rows = (size.height / verticalSpacing).ceil();
    final path = Path();

    for (var column = -1; column <= columns; column++) {
      final centerX = column * horizontalSpacing;
      final rowOffset = column.isEven ? 0.0 : verticalSpacing / 2;
      for (var row = -1; row <= rows; row++) {
        final centerY = row * verticalSpacing + rowOffset;
        for (var vertex = 0; vertex < 6; vertex++) {
          final angle = math.pi / 3 * vertex;
          final point = Offset(
            centerX + radius * math.cos(angle),
            centerY + radius * math.sin(angle),
          );
          if (vertex == 0) {
            path.moveTo(point.dx, point.dy);
          } else {
            path.lineTo(point.dx, point.dy);
          }
        }
        path.close();
      }
    }
    _cachedHexSize = size;
    _cachedHexRadius = radius;
    _cachedHexPath = path;
    return path;
  }

  @override
  bool shouldRepaint(covariant _BumpCloudFogPainter oldDelegate) =>
      oldDelegate.camera != camera ||
      oldDelegate.boundaryPoints != boundaryPoints ||
      oldDelegate.territoryBoundaries != territoryBoundaries ||
      oldDelegate.fogEnabled != fogEnabled;
}

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
            color: const Color(0xD92B180C),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x80FFB74D)),
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
                    color: Color(0xFFFFB74D),
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
                      color: Color(0xFFFFF8F0),
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
