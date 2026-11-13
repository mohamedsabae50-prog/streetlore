import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';

class RouteOnMapButton extends StatelessWidget {
  const RouteOnMapButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    key: const ValueKey('route-on-map-button'),
    onPressed: onPressed,
    icon: const Icon(Icons.route_rounded, size: 17),
    label: Text(context.tr('route_on_map')),
    style: TextButton.styleFrom(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    ),
  );
}

class MapRouteHud extends StatelessWidget {
  const MapRouteHud({
    super.key,
    required this.destinationName,
    required this.distance,
    required this.estimatedMinutes,
    required this.isLoading,
    required this.isArrived,
    required this.onEndRoute,
  });

  final String destinationName;
  final String distance;
  final int estimatedMinutes;
  final bool isLoading;
  final bool isArrived;
  final VoidCallback onEndRoute;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('map-route-hud'),
      color: Theme.of(context).cardColor,
      elevation: 8,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.navigation_rounded, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    destinationName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('end-route-button'),
                  onPressed: onEndRoute,
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: Text(context.tr('end_route')),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              isArrived
                  ? context.tr('route_arrived')
                  : isLoading
                  ? context.tr('route_calculating')
                  : context.tr('route_distance_eta', {
                      'distance': distance,
                      'minutes': '$estimatedMinutes',
                    }),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
