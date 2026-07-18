import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/animations/app_animations.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../logic/place_provider.dart';
import '../../logic/tour_provider.dart';
import '../widgets/place_card.dart';
import '../widgets/tour_card.dart';
import 'place_details_screen.dart';
import 'tour_details_screen.dart';

class SavedToursScreen extends StatefulWidget {
  const SavedToursScreen({super.key});

  @override
  State<SavedToursScreen> createState() => _SavedToursScreenState();
}

class _SavedToursScreenState extends State<SavedToursScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your collection',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text('Saved', style: AppTextStyles.screenTitle),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AppColors.textSecondary.withValues(alpha: 0.15),
                  ),
                ),
                child: TabBar(
                  controller: _tabCtrl,
                  indicator: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  indicatorPadding: const EdgeInsets.all(3),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                  tabs: const [
                    Tab(text: 'Places'),
                    Tab(text: 'Tours'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                physics: const BouncingScrollPhysics(),
                children: const [_SavedPlacesTab(), _SavedToursTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedPlacesTab extends StatelessWidget {
  const _SavedPlacesTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaceProvider>(
      builder: (context, placeProvider, _) {
        final places = placeProvider.savedPlaces;

        if (places.isEmpty) {
          return _EmptyState(
            icon: Icons.bookmark_outline_rounded,
            title: 'No Saved Places',
            subtitle:
                'Start exploring and tap the bookmark icon on any place to save it here for easy access.',
            actionLabel: 'Discover Places',
            onAction: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Switch to the Explore tab to discover places!',
                  ),
                ),
              );
            },
          );
        }

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${places.length} saved',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '<- Swipe left to remove',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () =>
                          _showClearPlacesDialog(context, placeProvider),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              size: 14,
                              color: AppColors.error,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Clear',
                              style: TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final place = places[index];
                return Dismissible(
                  key: Key('saved_place_${place.id}'),
                  direction: DismissDirection.endToStart,
                  background: _deleteBackground(),
                  onDismissed: (_) {
                    placeProvider.toggleSave(place);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${place.name} removed from saved places',
                        ),
                        action: SnackBarAction(
                          label: 'Undo',
                          textColor: AppColors.ratingGold,
                          onPressed: () => placeProvider.toggleSave(place),
                        ),
                      ),
                    );
                  },
                  child: PlaceCard(
                    place: place,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlaceDetailsScreen(place: place),
                        ),
                      );
                    },
                  ),
                );
              }, childCount: places.length),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        );
      },
    );
  }

  void _showClearPlacesDialog(BuildContext context, PlaceProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Text(
          'Clear All Saved Places?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            fontSize: 18,
          ),
        ),
        content: const Text(
          'This will permanently remove all your saved places. This cannot be undone.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              provider.clearAllSaved();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All saved places cleared.'),
                  backgroundColor: AppColors.error,
                ),
              );
            },
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _SavedToursTab extends StatelessWidget {
  const _SavedToursTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<TourProvider>(
      builder: (context, tourProvider, _) {
        final tours = tourProvider.savedTours;

        if (tours.isEmpty) {
          return _EmptyState(
            icon: Icons.map_outlined,
            title: 'No Saved Tours',
            subtitle:
                'Tap the download icon on any tour to save it here for offline access.',
            actionLabel: 'Browse Tours',
            onAction: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Switch to the Tours tab to discover tours!'),
                ),
              );
            },
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(top: 8),
          itemCount: tours.length,
          itemBuilder: (context, i) {
            final tour = tours[i];
            return FadeInUp(
              delay: Duration(milliseconds: 80 * i + 200),
              offsetY: 24,
              child: TourCard(
                tour: tour,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TourDetailsScreen(tour: tour),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.08),
                    AppColors.accent.withValues(alpha: 0.06),
                  ],
                ),
              ),
              child: Icon(icon, size: 54, color: AppColors.primary),
            ),
            const SizedBox(height: 28),
            Text(
              title,
              style: AppTextStyles.displayMedium.copyWith(fontSize: 22),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 36),
            Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: onAction,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.explore_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(actionLabel, style: AppTextStyles.buttonText),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _deleteBackground() => Container(
  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
  decoration: BoxDecoration(
    gradient: const LinearGradient(
      colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
    ),
    borderRadius: BorderRadius.circular(20),
  ),
  alignment: Alignment.centerRight,
  padding: const EdgeInsets.only(right: 24),
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: const [
      Icon(Icons.delete_rounded, color: Colors.white, size: 28),
      SizedBox(height: 4),
      Text(
        'Remove',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  ),
);
