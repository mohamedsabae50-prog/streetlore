import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/place_model.dart';
import '../../l10n/app_strings.dart';
import '../../logic/place_provider.dart';
import '../../logic/trip_provider.dart';

/// v1.0.75 — single-hub Trip Planner with two tabs:
///   • Saved  — places the user tapped the bookmark on (PlaceProvider.savedPlaces)
///   • Visited — places the user checked in to (TripProvider.visitedPlaceIds joined
///     with the live places table)
/// The old "_tripPlaces" manual list still works for the rare flow where a
/// user explicitly adds a place to their custom trip; we expose it as an
/// "Planner" tab when there is anything in it.
class TripPlannerScreen extends StatelessWidget {
  const TripPlannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: context.bgColor,
        appBar: AppBar(
          title: Text(
            context.tr('trip_title'),
            style: TextStyle(
              color: context.textPri,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: context.textPri),
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelColor: AppColors.primary,
            unselectedLabelColor: context.textSec,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
            tabs: [
              Tab(
                icon: Icon(Icons.bookmark_rounded, size: 18),
                text: context.tr('trip_tab_saved'),
              ),
              Tab(
                icon: Icon(Icons.check_circle_rounded, size: 18),
                text: context.tr('trip_tab_visited'),
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _SavedTab(),
            _VisitedTab(),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Saved tab — reads PlaceProvider.savedPlaces (synced with Supabase in
// place_provider.dart, see toggleSave() there).
// =============================================================================
class _SavedTab extends StatelessWidget {
  const _SavedTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaceProvider>(
      builder: (context, pp, _) {
        final saved = pp.savedPlaces;
        if (saved.isEmpty) {
          return _Empty(
            icon: Icons.bookmark_outline_rounded,
            title: context.tr('trip_tab_saved_empty_title'),
            body: context.tr('trip_tab_saved_empty_body'),
          );
        }
        return _SavedList(saved: saved);
      },
    );
  }
}

class _SavedList extends StatelessWidget {
  final List<PlaceModel> saved;
  const _SavedList({required this.saved});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      itemCount: saved.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _PlaceCard(
        place: saved[i],
        isVisited: context.read<TripProvider>().isVisited(saved[i].id),
      ),
    );
  }
}

// =============================================================================
// Visited tab — joins TripProvider.visitedPlaceIds with the live places
// table from PlaceProvider.places, so the user always sees the rich
// data (name, image, category) for every place they checked in at.
// =============================================================================
class _VisitedTab extends StatefulWidget {
  const _VisitedTab();

  @override
  State<_VisitedTab> createState() => _VisitedTabState();
}

class _VisitedTabState extends State<_VisitedTab> {
  @override
  void initState() {
    super.initState();
    // Make sure the visited set is loaded when the tab opens (in case
    // the user signed in *after* the provider was first constructed).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TripProvider>().refreshVisited();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<TripProvider, PlaceProvider>(
      builder: (context, trip, places, _) {
        final ids = trip.visitedPlaceIds;
        if (ids.isEmpty) {
          return _Empty(
            icon: Icons.flag_outlined,
            title: context.tr('trip_tab_visited_empty_title'),
            body: context.tr('trip_tab_visited_empty_body'),
          );
        }
        // Match visited ids against the loaded catalog. Use the first
        // matching place per id so the same place doesn't appear twice
        // if there are duplicate rows in place_checkins.
        final visitedPlaces = <PlaceModel>[];
        final seen = <String>{};
        for (final p in places.places) {
          if (ids.contains(p.id) && !seen.contains(p.id)) {
            visitedPlaces.add(p);
            seen.add(p.id);
          }
        }
        if (visitedPlaces.isEmpty) {
          return _Empty(
            icon: Icons.flag_outlined,
            title: context.tr('trip_tab_visited_empty_title'),
            body: context.tr('trip_tab_visited_empty_body'),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          itemCount: visitedPlaces.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _PlaceCard(
            place: visitedPlaces[i],
            isVisited: true,
          ),
        );
      },
    );
  }
}

// =============================================================================
// Shared card widget
// =============================================================================
class _PlaceCard extends StatelessWidget {
  final PlaceModel place;
  final bool isVisited;
  const _PlaceCard({required this.place, required this.isVisited});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Card(
          color: context.cardColor,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isVisited
                ? BorderSide(color: AppColors.success.withValues(alpha: 0.6), width: 1.5)
                : BorderSide.none,
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 60,
                height: 60,
                child: Stack(
                  children: [
                    CachedNetworkImage(
                      imageUrl: place.imageUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      memCacheWidth: 120,
                      memCacheHeight: 120,
                      httpHeaders: const {
                        'User-Agent':
                            'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15',
                      },
                      placeholder: (_, __) => Container(
                        width: 60,
                        height: 60,
                        color: context.bgAlt,
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 60,
                        height: 60,
                        color: const Color(0xFF1C2433),
                        child: const Icon(
                          Icons.image_rounded,
                          color: Colors.white30,
                          size: 36,
                        ),
                      ),
                    ),
                    if (isVisited)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            title: Text(
              place.localizedName(locale),
              style: TextStyle(
                color: context.textPri,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              place.category,
              style: TextStyle(color: context.textSec, fontSize: 12),
            ),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: context.textSec,
            ),
            onTap: () {
              // Push the standard Place Details screen — the user can
              // then un-save / un-visit from there.
              Navigator.pushNamed(context, '/placeDetails',
                  arguments: place);
            },
          ),
        ),
        if (isVisited)
          Positioned(
            top: -8,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                context.tr('trip_visited_badge'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _Empty({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 72, color: context.hintColor),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textPri,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textSec, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}