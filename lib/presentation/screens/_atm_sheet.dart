import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_strings.dart';
import '../../data/models/map_poi.dart';

class AtmSheet extends StatelessWidget {
  final MapPoi atm;
  final ValueChanged<MapPoi>? onRoute;
  final Future<bool> Function(Uri uri)? launchMapUrl;
  const AtmSheet({
    super.key,
    required this.atm,
    this.onRoute,
    this.launchMapUrl,
  });

  Future<void> _openDirections(BuildContext context) async {
    final destination = Uri.encodeComponent(
      '${atm.name}, ${atm.address}, ${atm.governorate}',
    );
    final directionsUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$destination&travelmode=walking',
    );
    final searchUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query='
      '${Uri.encodeComponent('${atm.name} ${atm.lat},${atm.lng}')}',
    );
    final launcher = launchMapUrl;
    try {
      if (await (launcher?.call(directionsUri) ??
          launchUrl(
            directionsUri,
            mode: LaunchMode.externalApplication,
          ))) {
        return;
      }
    } catch (error, stackTrace) {
      debugPrint('AtmSheet: Google Maps directions failed: $error\n$stackTrace');
    }
    try {
      if (await (launcher?.call(searchUri) ??
          launchUrl(searchUri, mode: LaunchMode.externalApplication))) {
        return;
      }
    } catch (error, stackTrace) {
      debugPrint('AtmSheet: Google Maps search fallback failed: $error\n$stackTrace');
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open Google Maps.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).hintColor.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('atm-open-google-maps-button'),
                onPressed: () => _openDirections(context),
                icon: const Icon(Icons.map_rounded, size: 19),
                label: Text(
                  Localizations.localeOf(context).languageCode == 'ar'
                      ? 'فتح في خرائط جوجل'
                      : 'Open in Google Maps',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: atm.color,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: atm.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: atm.color.withValues(alpha: 0.35),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(atm.icon, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (atm.brand ?? 'ATM').toUpperCase(),
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        atm.name,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.titleMedium?.color,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        atm.address,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodySmall?.color,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                if (onRoute != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('atm-route-on-map-button'),
                      onPressed: () => onRoute!(atm),
                      icon: const Icon(Icons.route_rounded, size: 19),
                      label: Text(
                        context.tr('route_on_map'),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: atm.color,
                        minimumSize: const Size.fromHeight(48),
                        side: BorderSide(color: atm.color),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  )
                else
                  const Spacer(),
                const SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(
                    color: atm.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: atm.color),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
