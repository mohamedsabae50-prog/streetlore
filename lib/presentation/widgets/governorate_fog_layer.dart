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
    ..addPolygon(boundaryPoints, true);
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

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              key: const ValueKey('governorate-cloud-fog'),
              painter: _BumpCloudFogPainter(
                camera: camera,
                boundaryPoints: boundaryPoints,
                fogEnabled: provider.fogEnabled,
              ),
            ),
          ),
        ),
        if (provider.fogEnabled)
          MarkerLayer(
            markers: [
              for (final item in fogged)
                Marker(
                  point: LatLng(item.centerLat, item.centerLng),
                  width: 124,
                  height: 34,
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

class _BumpCloudFogPainter extends CustomPainter {
  const _BumpCloudFogPainter({
    required this.camera,
    required this.boundaryPoints,
    required this.fogEnabled,
  });

  final MapCamera camera;
  final List<Offset> boundaryPoints;
  final bool fogEnabled;

  @override
  void paint(Canvas canvas, Size size) {
    if (boundaryPoints.length < 3) return;

    final boundaryPath = Path()..addPolygon(boundaryPoints, true);
    if (fogEnabled) {
      final cutoutPath = buildGovernorateFogCutoutPath(size, boundaryPoints);
      canvas.drawPath(
        cutoutPath,
        Paint()
          ..color = const Color(0xF2050811)
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );

      canvas.save();
      canvas.clipPath(cutoutPath);
      canvas.drawPath(
        boundaryPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 26
          ..color = const Color(0xD9050811)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
      _drawCloudPuffs(canvas, size);
      canvas.restore();
    }

    canvas.drawPath(
      boundaryPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = const Color(0x9900E5FF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      boundaryPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = const Color(0xFF00E5FF)
        ..isAntiAlias = true,
    );
    canvas.drawPath(
      boundaryPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = const Color(0xAA55E6C1)
        ..isAntiAlias = true,
    );
  }

  void _drawCloudPuffs(Canvas canvas, Size size) {
    var index = 0;
    for (var latitude = 19; latitude <= 35; latitude += 4) {
      for (var longitude = 21; longitude <= 37; longitude += 4) {
        final point = camera.latLngToScreenPoint(
          LatLng(latitude.toDouble(), longitude.toDouble()),
        );
        _drawPuff(canvas, Offset(point.x, point.y), 44 + (index % 4) * 9);
        index++;
      }
    }

    for (var y = -60.0; y <= size.height + 60; y += 150) {
      for (var x = -60.0; x <= size.width + 60; x += 150) {
        final seed = index++;
        final jitterX = math.sin(seed * 12.9898) * 28;
        final jitterY = math.cos(seed * 7.233) * 24;
        _drawPuff(
          canvas,
          Offset(x + jitterX, y + jitterY),
          48 + (seed % 5) * 8,
        );
      }
    }

    for (var i = 0; i < boundaryPoints.length; i++) {
      final point = boundaryPoints[i];
      _drawPuff(canvas, point, 50 + (i % 4) * 7);
      if (i.isEven) {
        final next = boundaryPoints[(i + 1) % boundaryPoints.length];
        _drawPuff(canvas, Offset.lerp(point, next, 0.5)!, 44 + (i % 3) * 8);
      }
    }
  }

  void _drawPuff(Canvas canvas, Offset center, double radius) {
    final gradient = RadialGradient(
      colors: const [
        Color(0xFF24324A),
        Color(0xFF161F30),
        Color(0xFF0B101B),
        Color(0x00101624),
      ],
      stops: const [0, 0.36, 0.72, 1],
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = gradient.createShader(
          Rect.fromCircle(center: center, radius: radius),
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28)
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _BumpCloudFogPainter oldDelegate) =>
      oldDelegate.camera != camera ||
      oldDelegate.boundaryPoints != boundaryPoints ||
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
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xE6162433),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.55),
          ),
          boxShadow: const [BoxShadow(color: Color(0x4400E5FF), blurRadius: 9)],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (count == 0) const Text('🔒', style: TextStyle(fontSize: 11)),
              if (count > 0)
                const Icon(
                  Icons.place_rounded,
                  size: 13,
                  color: Color(0xFF55E6C1),
                ),
              const SizedBox(width: 4),
              Flexible(
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
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
