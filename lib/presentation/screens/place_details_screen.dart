import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/animations/app_animations.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_image.dart';
import '../../core/widgets/confetti_overlay.dart';
import '../../core/widgets/shimmer_image.dart';
import '../../data/mock_data.dart';
import '../../data/models/place_model.dart';
import '../../logic/gamification_provider.dart';
import '../../logic/place_provider.dart';
import '../../logic/review_provider.dart';
import '../../logic/streak_provider.dart';
import '../../data/models/review_model.dart';
import '../../l10n/app_strings.dart';
import '../widgets/add_review_sheet.dart';
import '../widgets/place_photos_section.dart';
import 'map_screen.dart';

class PlaceDetailsScreen extends StatefulWidget {
  final PlaceModel place;
  const PlaceDetailsScreen({super.key, required this.place});

  @override
  State<PlaceDetailsScreen> createState() => _PlaceDetailsScreenState();
}

class _PlaceDetailsScreenState extends State<PlaceDetailsScreen>
    with TickerProviderStateMixin {
  late final AnimationController _contentCtrl;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;
  final ConfettiController _confetti = ConfettiController();

  bool _isVisited = false;
  final List<PlaceModel> _nearby = [];

  @override
  void initState() {
    super.initState();
    _contentCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _contentFade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _contentCtrl, curve: Curves.easeIn));
    _contentSlide =
        Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(
          CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOutCubic),
        );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshNearby();
    });
  }

  void _refreshNearby() {
    if (!mounted) return;
    final allPlaces = context.read<PlaceProvider>().places;
    final current = widget.place;
    setState(() {
      _nearby
        ..clear()
        ..addAll(allPlaces
            .where((p) =>
                p.id != current.id &&
                (p.lat - current.lat).abs() < 0.05 &&
                (p.lng - current.lng).abs() < 0.05)
            .take(4));
    });
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  bool get _isOpen => MockData.isOpenNow(widget.place.openHours);

  void _openMaps() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(
          destinationLat: widget.place.lat,
          destinationLng: widget.place.lng,
          placeName: widget.place.name,
        ),
      ),
    );
  }

  void _showShareSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ShareSheet(place: widget.place),
    );
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place;
    final theme = Theme.of(context);
    final scaffoldBgColor = theme.scaffoldBackgroundColor;
    final textPri = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final textSec = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    return Scaffold(
      backgroundColor: scaffoldBgColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: _GlassBtn(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.pop(context),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Consumer<PlaceProvider>(
              builder: (context, pp, _) {
                final saved = pp.isSaved(place.id);
                return _GlassBtn(
                  icon: saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  iconColor: saved ? AppColors.ratingGold : Colors.white,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    pp.toggleSave(place);
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: _GlassBtn(icon: Icons.share_rounded, onTap: _showShareSheet),
          ),
        ],
      ),
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            automaticallyImplyLeading: false,
            expandedHeight: 320,
            pinned: false,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'place-image-${place.id}',
                    flightShuttleBuilder: (
                      BuildContext flightContext,
                      Animation<double> animation,
                      HeroFlightDirection flightDirection,
                      BuildContext fromHeroContext,
                      BuildContext toHeroContext,
                    ) {
                      return Material(
                        color: Colors.transparent,
                        child: (toHeroContext.widget as Hero).child,
                      );
                    },
                    child: ShimmerImage(
                      imageUrl: place.imageUrl,
                      fit: BoxFit.cover,
                      fallbackIcon: Icons.broken_image_rounded,
                      fallbackColor: Colors.white38,
                      fallbackIconSize: 60,
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Color(0x880F172A),
                          Color(0xEE0F172A),
                        ],
                        stops: [0.4, 0.7, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 100,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isOpen
                              ? AppColors.success.withValues(alpha: 0.6)
                              : AppColors.error.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: _isOpen
                                  ? AppColors.success
                                  : AppColors.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _isOpen
                                ? context.tr('open_now')
                                : context.tr('closed'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 80,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Hero(
                          tag: 'place-category-${place.id}',
                          flightShuttleBuilder: (
                            BuildContext flightContext,
                            Animation<double> animation,
                            HeroFlightDirection flightDirection,
                            BuildContext fromHeroContext,
                            BuildContext toHeroContext,
                          ) {
                            return Material(
                              type: MaterialType.transparency,
                              child: (toHeroContext.widget as Hero).child,
                            );
                          },
                          child: Material(
                            type: MaterialType.transparency,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                place.category.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Hero(
                          tag: 'place-name-${place.id}',
                          flightShuttleBuilder: (
                            BuildContext flightContext,
                            Animation<double> animation,
                            HeroFlightDirection flightDirection,
                            BuildContext fromHeroContext,
                            BuildContext toHeroContext,
                          ) {
                            return DefaultTextStyle(
                              style: DefaultTextStyle.of(toHeroContext).style,
                              child: (toHeroContext.widget as Hero).child,
                            );
                          },
                          child: Material(
                            type: MaterialType.transparency,
                            child: Text(
                              place.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: AppColors.ratingGold,
                            size: 20,
                          ),
                          Text(
                            place.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
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
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _contentFade,
              child: SlideTransition(
                position: _contentSlide,
                child: Container(
                  decoration: BoxDecoration(
                    color: scaffoldBgColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  transform: Matrix4.translationValues(0, -28, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Consumer<PlaceProvider>(
                                builder: (context, pp, _) {
                                  final saved = pp.isSaved(place.id);
                                  return _QuickAction(
                                    icon: saved
                                        ? Icons.bookmark_rounded
                                        : Icons.bookmark_border_rounded,
                                    label: saved
                                        ? context.tr('saved')
                                        : context.tr('save'),
                                    color: saved
                                        ? AppColors.ratingGold
                                        : AppColors.primary,
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      pp.toggleSave(place);
                                    },
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _QuickAction(
                                icon: _isVisited
                                    ? Icons.check_circle_rounded
                                    : Icons.flag_outlined,
                                label: _isVisited
                                    ? context.tr('visited')
                                    : context.tr('checkin'),
                                color: AppColors.success,
                                onTap: () async {
                                  HapticFeedback.mediumImpact();
                                  final wasVisited = _isVisited;
                                  setState(() => _isVisited = !_isVisited);
                                  if (!wasVisited) {
                                    final streak = context.read<StreakProvider>();
                                    final gamification =
                                        context.read<GamificationProvider>();
                                    final messenger = ScaffoldMessenger.of(context);
                                    final newStreak =
                                        await streak.registerVisit();
                                    await gamification.applyAction('check_in');
                                    final milestoneBadge = await gamification
                                        .checkStreakMilestone(newStreak);
                                    if (milestoneBadge != null) {
                                      HapticFeedback.heavyImpact();
                                      _confetti.play();
                                    } else if (newStreak > 1 &&
                                        newStreak % 3 == 0) {
                                      _confetti.play();
                                    }
                                    if (!context.mounted) return;
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            const Icon(
                                                Icons.local_fire_department_rounded,
                                                color: Colors.white,
                                                size: 18),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                milestoneBadge != null
                                                    ? context.tr(
                                                        'badge_unlocked',
                                                        {
                                                          'name': context.tr(
                                                              milestoneBadge
                                                                  .name),
                                                        },
                                                      )
                                                    : context.tr(
                                                        'checked_in_streak',
                                                        {'n': '$newStreak'},
                                                      ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        backgroundColor:
                                            AppColors.success,
                                      ),
                                    );
                                  } else {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            const Icon(
                                                Icons.cancel_rounded,
                                                color: Colors.white,
                                                size: 18),
                                            const SizedBox(width: 8),
                                            Text(context
                                                .tr('checkin_removed')),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _QuickAction(
                                icon: Icons.directions_rounded,
                                label: context.tr('go'),
                                color: AppColors.primary,
                                onTap: _openMaps,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _PriceBanner(place: place),
                            const SizedBox(height: 22),
                            Row(
                              children: [
                                Text(
                                  context.tr('about_place'),
                                  style: TextStyle(
                                    color: textPri,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              place.description,
                              style: TextStyle(
                                color: textSec,
                                fontSize: 15,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),

                      
                      PlacePhotosSection(place: place),
                      const SizedBox(height: 24),
                      _ReviewsSection(place: place),

                      
                      if (_nearby.isNotEmpty)
                        _NearbySection(places: _nearby),

                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
          ),
          ConfettiOverlay(controller: _confetti),
        ],
      ),
      bottomSheet: _BookingBar(place: place),
    );
  }
}

class _GlassBtn extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  const _GlassBtn({
    required this.icon,
    this.iconColor = Colors.white,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      pressedScale: 0.88,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  final PlaceModel place;
  const _ReviewsSection({required this.place});

  @override
  Widget build(BuildContext context) {
    final reviewProvider = Provider.of<ReviewProvider>(context);
    final reviews = reviewProvider.getReviewsForPlace(place.id);
    final theme = Theme.of(context);
    final textPri = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final textSec = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr('community_reviews'),
                style: TextStyle(
                  color: textPri,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => AddReviewSheet(placeId: place.id),
                  );
                },
                child: Text(context.tr('write_review')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (reviews.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  context.tr('no_reviews'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textSec, fontSize: 14),
                ),
              ),
            )
          else
            ...reviews.take(3).map((r) => _ReviewItem(review: r)),
        ],
      ),
    );
  }
}

class _ReviewItem extends StatelessWidget {
  final ReviewModel review;
  const _ReviewItem({required this.review});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textPri = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final textSec = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  review.userName[0].toUpperCase(),
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.userName,
                      style: TextStyle(color: textPri, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Row(
                      children: List.generate(
                        5,
                        (index) => Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: index < review.rating ? AppColors.ratingGold : Colors.grey[300],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${review.date.day}/${review.date.month}/${review.date.year}',
                style: TextStyle(color: textSec, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            review.comment,
            style: TextStyle(color: textPri.withValues(alpha: 0.8), fontSize: 14, height: 1.4),
          ),
          if (review.imagePath != null && review.imagePath!.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AppImage(
                source: review.imagePath!,
                height: 170,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NearbySection extends StatelessWidget {
  final List<PlaceModel> places;
  const _NearbySection({required this.places});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textPri = theme.textTheme.bodyLarge?.color ?? Colors.black;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
          child: Text(
            context.tr('nearby_gems'),
            style: TextStyle(
              color: textPri,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: places.length,
            itemBuilder: (context, i) => FadeInUp(
              delay: Duration(milliseconds: 80 * i + 200),
              offsetY: 30,
              child: _NearbyCard(place: places[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _NearbyCard extends StatelessWidget {
  final PlaceModel place;
  const _NearbyCard({required this.place});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, animation, __) =>
              PlaceDetailsScreen(place: place),
          transitionDuration: const Duration(milliseconds: 450),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(
            opacity: animation,
            child: child,
          ),
        ),
      ),
      child: Container(
        width: 140,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'place-image-${place.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 110,
                  width: 140,
                  child: ShimmerImage(
                    imageUrl: place.imageUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              place.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingBar extends StatelessWidget {
  final PlaceModel place;
  const _BookingBar({required this.place});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('experience'),
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(
                  context.tr('book_tour'),
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge?.color),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(context.tr('book_now'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _ShareSheet extends StatelessWidget {
  final PlaceModel place;
  const _ShareSheet({required this.place});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.tr('share_app'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ShareIcon(icon: Icons.link, label: context.tr('copy_link')),
              _ShareIcon(icon: Icons.message, label: context.tr('message')),
              _ShareIcon(icon: Icons.email, label: context.tr('email')),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ShareIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ShareIcon({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
          child: Icon(icon, color: AppColors.primary),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _PriceBanner extends StatelessWidget {
  final PlaceModel place;
  const _PriceBanner({required this.place});

  Color get _accent {
    switch (place.priceLevel) {
      case PriceLevel.free:
        return const Color(0xFF10B981);
      case PriceLevel.cheap:
        return const Color(0xFF14B8A6);
      case PriceLevel.moderate:
        return const Color(0xFFF59E0B);
      case PriceLevel.expensive:
        return const Color(0xFFEF4444);
    }
  }

  IconData get _icon {
    switch (place.priceLevel) {
      case PriceLevel.free:
        return Icons.celebration_rounded;
      case PriceLevel.cheap:
        return Icons.local_offer_rounded;
      case PriceLevel.moderate:
        return Icons.payments_rounded;
      case PriceLevel.expensive:
        return Icons.diamond_rounded;
    }
  }

  String _titleFor(BuildContext context) {
    switch (place.priceLevel) {
      case PriceLevel.free:
        return context.tr('free_entry');
      case PriceLevel.cheap:
        return context.tr('budget_friendly');
      case PriceLevel.moderate:
        return context.tr('standard_ticket');
      case PriceLevel.expensive:
        return context.tr('premium_experience');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? _accent.withValues(alpha: 0.12)
        : _accent.withValues(alpha: 0.07);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_icon, color: _accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _titleFor(context),
                  style: TextStyle(
                    color: _accent,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                if (place.hasDualPrice) ...[
                  Row(
                    children: [
                      _PricePill(
                        label: context.tr('egyptians'),
                        price: 'EGP ${place.priceLocalEgp}',
                        accent: _accent,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 6),
                      _PricePill(
                        label: context.tr('foreigners'),
                        price: 'EGP ${place.priceForeignerEgp}',
                        accent: _accent,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ] else
                  Text(
                    place.priceNote.isEmpty
                        ? place.priceLevel.label
                        : place.priceNote,
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFF475569),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PricePill extends StatelessWidget {
  final String label;
  final String price;
  final Color accent;
  final bool isDark;
  const _PricePill({
    required this.label,
    required this.price,
    required this.accent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF64748B),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          Text(
            price,
            style: TextStyle(
              color: accent,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
