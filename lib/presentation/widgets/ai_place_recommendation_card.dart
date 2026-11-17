import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../data/models/place_model.dart';
import '../../l10n/app_strings.dart';
import '../screens/place_details_screen.dart';

class AiPlaceRecommendationCard extends StatelessWidget {
  const AiPlaceRecommendationCard({super.key, required this.place});

  final PlaceModel place;

  String _priceSummary(BuildContext context, String locale) {
    if (place.isFree) return context.tr('free');
    final local = place.priceLocalEgp;
    final foreigner = place.priceForeignerEgp;
    if (local != null && foreigner != null) {
      return locale == 'ar'
          ? '$local / $foreigner ج.م'
          : 'EGP $local / $foreigner';
    }
    return place.localizedPriceNote(locale).isNotEmpty
        ? place.localizedPriceNote(locale)
        : place.priceLevel.label;
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    void openPlace() {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PlaceDetailsScreen(place: place),
        ),
      );
    }

    return Card(
      margin: const EdgeInsetsDirectional.fromSTEB(46, 0, 0, 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: openPlace,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 76,
                  height: 82,
                  child: place.imageUrl.trim().isEmpty
                      ? const _PlaceImageFallback()
                      : CachedNetworkImage(
                          imageUrl: place.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => const _PlaceImageFallback(),
                          errorWidget: (_, _, _) => const _PlaceImageFallback(),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.localizedName(locale),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _CategoryBadge(label: place.localizedCategory(locale)),
                        Text(
                          '⭐ ${place.rating.toStringAsFixed(1)}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        Text(
                          _priceSummary(context, locale),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    FilledButton.tonal(
                      onPressed: openPlace,
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: const Size(0, 32),
                      ),
                      child: Text(context.tr('ai_place_view')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _PlaceImageFallback extends StatelessWidget {
  const _PlaceImageFallback();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Icon(
      Icons.place_rounded,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      size: 28,
    ),
  );
}
