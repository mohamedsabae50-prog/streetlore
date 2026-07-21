import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';
import 'trip_planner_screen.dart';
import '../../core/animations/app_animations.dart';
import '../../core/services/compass_service.dart';
import '../../core/widgets/animated_icons.dart';
import '../../core/widgets/shimmer_image.dart';
import '../../logic/trip_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/place_model.dart';
import '../../logic/auth_provider.dart';
import '../../logic/place_provider.dart';
import '../../logic/tour_provider.dart';
import '../widgets/place_card.dart';
import '../widgets/featured_card.dart';
import '../widgets/weather_widget.dart';
import '../../l10n/app_strings.dart';
import 'place_details_screen.dart';
import 'ai_trip_generator_screen.dart';
import 'leaderboard_screen.dart';
import 'map_view_screen.dart';
import 'public_transport_screen.dart';
import 'journal_screen.dart';
import 'offline_mode_screen.dart';
import 'geofencing_settings_screen.dart';
import 'best_time_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  bool _isLoading = true;
  String _selectedCategory = 'All';
  bool _freeOnly = false;
  bool _hiddenGemsOnly = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();
  bool _isSearchFocused = false;

  late final AnimationController _headerCtrl;
  late final Animation<double> _headerFade;

  late final AnimationController _compassCtrl;
  late final Animation<double> _compassScale;
  late final Animation<double> _compassRotation;
  late final Animation<double> _compassOffset;
  late final AnimationController _compassPulseCtrl;
  late final Animation<double> _compassPulse;
  late final AnimationController _compassIconCtrl;
  late final Animation<double> _compassIconRotation;
  double _compassHeadingDeg = 0;
  StreamSubscription<double>? _compassSub;

  final List<_CategoryItem> _categories = const [
    _CategoryItem(label: 'All', icon: Icons.apps_rounded),
    _CategoryItem(label: 'Historical', icon: Icons.account_balance_rounded),
    _CategoryItem(label: 'Culture', icon: Icons.museum_rounded),
    _CategoryItem(label: 'Nature', icon: Icons.park_rounded),
    _CategoryItem(label: 'Food', icon: Icons.restaurant_rounded),
    _CategoryItem(label: 'Shopping', icon: Icons.shopping_bag_rounded),
    _CategoryItem(label: 'Mosques', icon: Icons.mosque_rounded),
    _CategoryItem(label: 'Churches', icon: Icons.church_rounded),
    _CategoryItem(label: 'Streets', icon: Icons.signpost_rounded),
  ];
  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _headerFade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _headerCtrl, curve: Curves.easeIn));

    _compassCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..forward();
    _compassScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.65, end: 1.1), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 45),
    ]).animate(CurvedAnimation(parent: _compassCtrl, curve: Curves.easeOut));

    _compassRotation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: -0.45, end: 0.35), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 0.35, end: -0.15), weight: 30),
      TweenSequenceItem(tween: Tween(begin: -0.15, end: 0.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _compassCtrl, curve: Curves.easeOut));

    _compassOffset = Tween<double>(begin: 26, end: 0).animate(
      CurvedAnimation(parent: _compassCtrl, curve: Curves.easeOutQuint),
    );

    _compassPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _compassPulse =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 50),
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 50),
        ]).animate(
          CurvedAnimation(parent: _compassPulseCtrl, curve: Curves.easeInOut),
        );

    _compassIconCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _compassIconRotation = Tween<double>(
      begin: 0.0,
      end: 2 * pi,
    ).animate(CurvedAnimation(parent: _compassIconCtrl, curve: Curves.linear));

    Future.delayed(const Duration(milliseconds: 950), () {
      if (mounted) {
        _compassPulseCtrl.repeat(reverse: true);
      }
    });

    CompassService.instance.start();
    _compassSub = CompassService.instance.headingStream.listen((deg) {
      if (!mounted) return;
      setState(() {
        _compassHeadingDeg = deg;
        if (!CompassService.instance.isActuallyWorking) {
          _compassIconCtrl.repeat();
        } else {
          _compassIconCtrl.stop();
          _compassIconCtrl.value = 0;
        }
      });
    });

    _searchFocus.addListener(
      () => setState(() => _isSearchFocused = _searchFocus.hasFocus),
    );
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _scrollCtrl.dispose();
    _headerCtrl.dispose();
    _compassCtrl.dispose();
    _compassPulseCtrl.dispose();
    _compassIconCtrl.dispose();
    _compassSub?.cancel();
    super.dispose();
  }

  String _getGreeting(BuildContext context) {
    final h = DateTime.now().hour;
    if (h < 12) return context.tr('greet_morning');
    if (h < 17) return context.tr('greet_afternoon');
    return context.tr('greet_evening');
  }

  List<PlaceModel> get _categoryFiltered {
    final all = context.read<PlaceProvider>().places;
    if (_selectedCategory == 'All') return all;
    return all.where((p) => p.category == _selectedCategory).toList();
  }

  String get _searchTerm => _searchQuery.trim().toLowerCase();

  bool get _isSearching => _searchTerm.isNotEmpty;

  List<PlaceModel> get _searchResults => context
      .read<PlaceProvider>()
      .places
      .where(
        (p) =>
            p.name.toLowerCase().contains(_searchTerm) ||
            p.description.toLowerCase().contains(_searchTerm),
      )
      .toList();

  List<PlaceModel> get _filtered {
    final base = _isSearching ? _searchResults : _categoryFiltered;
    var result = base;
    if (_freeOnly) result = result.where((p) => p.isFree).toList();
    if (_hiddenGemsOnly) result = result.where((p) => p.isHiddenGem).toList();
    return result;
  }

  Widget _buildCompassIntro() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _compassCtrl,
          _compassPulseCtrl,
        ]),
        builder: (context, _) {
          final pulseValue = _compassPulse.value;
          final pulseScale = 1.0 + pulseValue * 0.03;
          final glowAlpha = (pulseValue * 32).clamp(0, 32).toInt();
          final hasCompass = CompassService.instance.isActuallyWorking;
          final angle = _compassHeadingDeg * (pi / 180.0);
          final dir = _compassDirLabel(_compassHeadingDeg);
          return Transform.translate(
            offset: Offset(0, _compassOffset.value),
            child: Transform.rotate(
              angle: _compassRotation.value,
              child: Transform.scale(
                scale: _compassScale.value * pulseScale,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: context.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: context.textSec.withValues(alpha: 0.1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4F46E5), Color(0xFF22C55E)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Color.fromARGB(glowAlpha, 79, 70, 229),
                              blurRadius: 16 + pulseValue * 8,
                              spreadRadius: pulseValue * 2,
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              top: 4,
                              child: Text(
                                'N',
                                style: TextStyle(
                                  color: Colors.white
                                      .withValues(alpha: 0.95),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Center(
                              child: Transform.rotate(
                                angle: hasCompass
                                    ? -angle
                                    : _compassIconRotation.value,
                                child: const Icon(
                                  Icons.navigation_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  context.tr('compass_title'),
                                  style: TextStyle(
                                    color: context.textPri,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                if (hasCompass) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF22C55E)
                                          .withValues(alpha: 0.18),
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      dir,
                                      style: const TextStyle(
                                        color: Color(0xFF22C55E),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              hasCompass
                                  ? '${_compassHeadingDeg.round()}° · ${context.tr('compass_sub')}'
                                  : context.tr('compass_sub'),
                              style: TextStyle(
                                color: context.textSec,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _compassDirLabel(double deg) {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final i = ((deg % 360) / 45).round() % 8;
    return dirs[i];
  }

  void _openPlace(PlaceModel place) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => PlaceDetailsScreen(place: place),
        transitionDuration: const Duration(milliseconds: 550),
        reverseTransitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
            ),
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 0.04),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: const Interval(
                        0.3,
                        1.0,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                  ),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final filtered = _filtered;
    final isSearching = _isSearching;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            FadeTransition(
              opacity: _headerFade,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGreeting(context),
                            style: TextStyle(
                              fontSize: 13,
                              color: context.textSec,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [AppColors.primary, Color(0xFF22C55E)],
                            ).createShader(bounds),
                            child: const Text(
                              'Streetlore',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Consumer<TripProvider>(
                      builder: (context, tripP, _) {
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TripPlannerScreen(),
                              ),
                            );
                          },
                          child: _IconBtn(
                            icon: Icons.map_outlined,
                            badge: tripP.tripPlaces.isNotEmpty,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const GeofencingSettingsScreen(),
                          ),
                        );
                      },
                      child: const _IconBtn(
                        icon: Icons.notifications_outlined,
                        badge: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            width: 2,
                          ),
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, Color(0xFF4F46E5)],
                          ),
                        ),
                        child: Center(
                          child: Text(
                            auth.userName.isNotEmpty
                                ? auth.userName[0].toUpperCase()
                                : 'E',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildCompassIntro(),
            const WeatherWidget(),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _isSearchFocused
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.06),
                      blurRadius: _isSearchFocused ? 16 : 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: _isSearchFocused
                        ? AppColors.primary.withValues(alpha: 0.45)
                        : context.textSec.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  style: TextStyle(
                    color: context.textPri,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: context.tr('search_hint'),
                    hintStyle: TextStyle(
                      color: context.textSec.withValues(alpha: 0.5),
                      fontSize: 15,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: _isSearchFocused
                          ? context.textPri
                          : context.textSec,
                      size: 22,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: context.textSec,
                              size: 20,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                              _searchFocus.unfocus();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),

            Expanded(
              child: _isLoading
                  ? _buildShimmer()
                  : isSearching
                  ? _buildSearchResults(filtered)
                  : _buildMain(filtered),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMain(List<PlaceModel> filtered) {
    final placeProvider = context.watch<PlaceProvider>();
    final featured = placeProvider.places;
    final List<PlaceModel> displayedPlaces = placeProvider.applyFilters(
      featured,
    );

    return RefreshIndicator(
      color: context.textPri,
      onRefresh: () async {
        await context.read<PlaceProvider>().refresh();
        if (!mounted) return;
        await context.read<TourProvider>().refresh();
      },
      child: CustomScrollView(
        controller: _scrollCtrl,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.tr('featured'),
                        style: AppTextStyles.sectionTitle.copyWith(
                          color: context.textPri,
                        ),
                      ),
                      Text(
                        context.tr('see_all'),
                        style: TextStyle(
                          color: context.textPri,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    children: [
                      FilterChip(
                        label: Text(context.tr('filter_open_now')),
                        selected: placeProvider.isFilterOpenNow,
                        onSelected: (_) => placeProvider.toggleFilterOpenNow(),
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        checkmarkColor: context.textPri,
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Text(context.tr('filter_cheapest')),
                        selected: placeProvider.isFilterCheapest,
                        onSelected: (_) => placeProvider.toggleFilterCheapest(),
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        checkmarkColor: context.textPri,
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Text(context.tr('filter_nearest')),
                        selected: placeProvider.isFilterNearest,
                        onSelected: (_) => placeProvider.toggleFilterNearest(),
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        checkmarkColor: context.textPri,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                AnimatedBuilder(
                  animation: _scrollCtrl,
                  builder: (context, staticChild) {
                    final o =
                        _scrollCtrl.hasClients ? _scrollCtrl.offset : 0.0;
                    return Transform.translate(
                      offset: Offset(0, -o * 0.25),
                      child: Opacity(
                        opacity: (1.0 - o / 350).clamp(0.0, 1.0),
                        child: staticChild,
                      ),
                    );
                  },
                  child: SizedBox(
                    height: 240,
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(left: 20, right: 6),
                      itemCount: displayedPlaces.length,
                      itemBuilder: (context, i) => FeaturedCard(
                        place: displayedPlaces[i],
                        onTap: () => _openPlace(displayedPlaces[i]),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 20),
              child: SizedBox(
                height: 42,
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _categories.length + 2,
                  itemBuilder: (context, i) {
                    if (i == _categories.length) {
                      return _FilterPill(
                        label: 'filter_free',
                        iconOn: Icons.check_circle_rounded,
                        iconOff: Icons.local_offer_rounded,
                        color: const Color(0xFF10B981),
                        active: _freeOnly,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _freeOnly = !_freeOnly);
                        },
                      );
                    }
                    if (i == _categories.length + 1) {
                      return _FilterPill(
                        label: 'filter_hidden_gems',
                        iconOn: Icons.diamond_rounded,
                        iconOff: Icons.diamond_outlined,
                        color: const Color(0xFF8B5CF6),
                        active: _hiddenGemsOnly,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _hiddenGemsOnly = !_hiddenGemsOnly);
                        },
                      );
                    }
                    final cat = _categories[i];
                    final isSel = _selectedCategory == cat.label;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _selectedCategory = cat.label);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsetsDirectional.only(end: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: isSel
                              ? AppColors.primary
                              : context.cardColor,
                          borderRadius: BorderRadius.circular(22),
                          border: isSel
                              ? null
                              : Border.all(
                                  color: context.textSec.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                          boxShadow: isSel
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.35,
                                    ),
                                    blurRadius: 12,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              cat.icon,
                              size: 14,
                              color: isSel
                                  ? Colors.white
                                  : context.textSec,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              context.tr('cat_${cat.label.toLowerCase()}'),
                              style: TextStyle(
                                color: isSel
                                    ? Colors.white
                                    : context.textSec,
                                fontWeight: isSel
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(child: _QuickAccessGrid()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedCategory == 'All'
                        ? context.tr('all_places')
                        : context.tr(
                            'cat_${_selectedCategory.toLowerCase()}'),
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: context.textPri,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      context.tr('places_count', {'n': '${filtered.length}'}),
                      style: TextStyle(
                        color: context.textPri,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          filtered.isEmpty
              ? SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 64,
                          color: context.textSec.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.tr('no_places'),
                          style: AppTextStyles.sectionTitle.copyWith(
                            color: context.textPri,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => FadeInUp(
                      delay: Duration(milliseconds: 60 * i + 200),
                      offsetY: 24,
                      child: PlaceCard(
                        place: filtered[i],
                        onTap: () => _openPlace(filtered[i]),
                      ),
                    ),
                    childCount: filtered.length,
                  ),
                ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildSearchResults(List<PlaceModel> results) {
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 90,
              height: 90,
              child: AnimatedLottieIcon(
                animation: LottieAnimations.radar,
                size: 90,
                color: context.textSec,
                secondaryColor: context.textPri,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('no_results_for', {'q': _searchQuery}),
              style: AppTextStyles.sectionTitle.copyWith(
                color: context.textPri,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('try_different'),
              style: TextStyle(
                color: context.textSec,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            context.tr('results_for', {
              'n': '${results.length}',
              'q': _searchQuery,
            }),
            style: TextStyle(
              color: context.textSec,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: results.length,
            itemBuilder: (context, i) => FadeInUp(
              delay: Duration(milliseconds: 50 * i + 100),
              offsetY: 24,
              child: PlaceCard(
                place: results[i],
                onTap: () => _openPlace(results[i]),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShimmer() {
    final base = context.shimmerBase;
    final highlight = context.shimmerHighlight;
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
            child: Shimmer.fromColors(
              baseColor: base,
              highlightColor: highlight,
              child: Container(
                width: 140,
                height: 20,
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 240,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 20),
              itemCount: 3,
              itemBuilder: (_, __) => Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Shimmer.fromColors(
                  baseColor: base,
                  highlightColor: highlight,
                  child: Container(
                    width: 190,
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          ...List.generate(
            4,
            (i) => FadeInUp(
              delay: Duration(milliseconds: 120 * i + 400),
              offsetY: 20,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                child: ShimmerCardPlaceholder(height: 120, imageHeight: 0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryItem {
  final String label;
  final IconData icon;
  const _CategoryItem({required this.label, required this.icon});
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final bool badge;
  const _IconBtn({required this.icon, this.badge = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.textSec.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          Center(child: Icon(icon, color: context.textPri, size: 22)),
          if (badge)
            Positioned(
              top: 9,
              right: 9,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.bgColor, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickAccessGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = <_QuickItem>[
      _QuickItem(
        icon: Icons.auto_awesome,
        label: 'quick_ai_trip',
        color: const Color(0xFF6366F1),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AiTripGeneratorScreen()),
        ),
      ),
      _QuickItem(
        icon: Icons.wb_twilight_rounded,
        label: 'quick_best_time',
        color: const Color(0xFFF59E0B),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BestTimeScreen()),
        ),
      ),
      _QuickItem(
        icon: Icons.map_rounded,
        label: 'quick_map',
        color: const Color(0xFF3B82F6),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MapViewScreen()),
        ),
      ),
      _QuickItem(
        icon: Icons.directions_transit_rounded,
        label: 'quick_transport',
        color: const Color(0xFFEC4899),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PublicTransportScreen()),
        ),
      ),
      _QuickItem(
        icon: Icons.menu_book_rounded,
        label: 'quick_journal',
        color: const Color(0xFF8B5CF6),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const JournalScreen()),
        ),
      ),
      _QuickItem(
        icon: Icons.emoji_events_rounded,
        label: 'quick_ranking',
        color: AppColors.warning,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
        ),
      ),
      _QuickItem(
        icon: Icons.cloud_off_rounded,
        label: 'quick_offline',
        color: const Color(0xFF7C3AED),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OfflineModeScreen()),
        ),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.tr('discover'),
                style: AppTextStyles.sectionTitle.copyWith(
                  color: context.textPri,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 20,
              crossAxisSpacing: 12,
              childAspectRatio: 0.7,
            ),
            itemBuilder: (context, i) => FadeInUp(
              delay: Duration(milliseconds: 50 * i + 100),
              offsetY: 20,
              child: _QuickCircleTile(item: items[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickCircleTile extends StatelessWidget {
  final _QuickItem item;

  const _QuickCircleTile({Key? key, required this.item}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.color.withOpacity(0.1),
              border: Border.all(
                color: item.color.withOpacity(0.3),
                width: 1.0,
              ),
            ),
            child: Center(child: Icon(item.icon, color: item.color, size: 26)),
          ),
          const SizedBox(height: 8),

          Text(
            context.tr(item.label),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final IconData iconOn;
  final IconData iconOff;
  final Color color;
  final bool active;
  final VoidCallback onTap;
  const _FilterPill({
    required this.label,
    required this.iconOn,
    required this.iconOff,
    required this.color,
    required this.active,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active ? color : context.cardColor,
          borderRadius: BorderRadius.circular(22),
          border: active
              ? null
              : Border.all(color: color.withValues(alpha: 0.4)),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? iconOn : iconOff,
              size: 14,
              color: active ? Colors.white : color,
            ),
            const SizedBox(width: 6),
            Text(
              context.tr(label),
              style: TextStyle(
                color: active ? Colors.white : color,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  _QuickItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}
