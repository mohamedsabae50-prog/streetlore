import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../data/models/egypt_governorate.dart';
import '../../data/models/place_model.dart';
import '../../logic/governorate_provider.dart';
import 'governorate_explorer_sheet.dart';

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
    final active =
        EgyptGovernorate.byId[provider.activeGovernorate] ??
        EgyptGovernorate.byId['alexandria']!;
    final fogged = EgyptGovernorate.all
        .where((item) => item.id != active.id)
        .toList(growable: false);

    return Stack(
      children: [
        PolygonLayer(
          polygons: [
            if (provider.fogEnabled)
              Polygon(
                points: const [
                  LatLng(18, 21),
                  LatLng(18, 39),
                  LatLng(35, 39),
                  LatLng(35, 21),
                ],
                holePointsList: [active.boundaryPolygon],
                color: const Color(0xCC060C18),
              ),
            Polygon(
              points: active.boundaryPolygon,
              color: Colors.transparent,
              borderColor: const Color(0xFF00E5FF),
              borderStrokeWidth: 2.5,
            ),
          ],
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
