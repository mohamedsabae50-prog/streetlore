import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';
import 'trip_planner_screen.dart';
import '../../core/animations/app_animations.dart';
import '../../core/widgets/animated_icons.dart';
import '../../core/widgets/shimmer_image.dart';
import '../../logic/trip_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/place_model.dart';
import '../../logic/auth_provider.dart';
import '../../logic/place_provider.dart';
import '../widgets/place_card.dart';
import '../widgets/featured_card.dart';
import '../widgets/weather_widget.dart';
import 'place_details_screen.dart';
import 'ai_trip_generator_screen.dart';
import 'leaderboard_screen.dart';
import 'map_view_screen.dart';
import 'currency_converter_screen.dart';
import 'public_transport_screen.dart';
import 'journal_screen.dart';
import 'community_routes_screen.dart';
import 'offline_mode_screen.dart';
import 'geofencing_settings_screen.dart';
import 'live_chat_screen.dart';
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
  double _scrollOffset = 0;

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
        _compassIconCtrl.repeat();
      }
    });

    _searchFocus.addListener(
      () => setState(() => _isSearchFocused = _searchFocus.hasFocus),
    );
    _scrollCtrl.addListener(() {
      if (mounted) setState(() => _scrollOffset = _scrollCtrl.offset);
    });
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
    super.dispose();
  }

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
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
          _compassIconCtrl,
        ]),
        builder: (context, _) {
          final pulseValue = _compassPulse.value;
          final pulseScale = 1.0 + pulseValue * 0.03;
          final glowAlpha = (pulseValue * 32).clamp(0, 32).toInt();
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
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.textSecondary.withValues(alpha: 0.1),
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
                        child: Center(
                          child: Transform.rotate(
                            angle: _compassIconRotation.value,
                            child: const Icon(
                              Icons.navigation_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Compass direction',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Discover the city with a sweeping animated compass that grows into place.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
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
      backgroundColor: AppColors.background,
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
                            _getGreeting(),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
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
                    const _IconBtn(
                      icon: Icons.notifications_outlined,
                      badge: true,
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
                  color: AppColors.cardBackground,
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
                        : AppColors.textSecondary.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search places, landmarks...',
                    hintStyle: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.5),
                      fontSize: 15,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: _isSearchFocused
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      size: 22,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: AppColors.textSecondary,
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

    return CustomScrollView(
      controller: _scrollCtrl,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Opacity(
            opacity: (1.0 - _scrollOffset / 120).clamp(0.0, 1.0),
            child: const WeatherWidget(),
          ),
        ),
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
                      'Featured',
                      style: AppTextStyles.sectionTitle.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Text(
                      'See all',
                      style: TextStyle(
                        color: AppColors.primary,
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
                      label: const Text('Open Now'),
                      selected: placeProvider.isFilterOpenNow,
                      onSelected: (_) => placeProvider.toggleFilterOpenNow(),
                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                      checkmarkColor: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Cheapest'),
                      selected: placeProvider.isFilterCheapest,
                      onSelected: (_) => placeProvider.toggleFilterCheapest(),
                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                      checkmarkColor: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Nearest'),
                      selected: placeProvider.isFilterNearest,
                      onSelected: (_) => placeProvider.toggleFilterNearest(),
                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                      checkmarkColor: AppColors.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              Transform.translate(
                offset: Offset(0, -_scrollOffset * 0.25),
                child: Opacity(
                  opacity: (1.0 - _scrollOffset / 350).clamp(0.0, 1.0),
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
                      label: 'Free only',
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
                      label: 'Hidden Gems',
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
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: isSel
                            ? AppColors.primary
                            : AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(22),
                        border: isSel
                            ? null
                            : Border.all(
                                color: AppColors.textSecondary.withValues(
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
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            cat.label,
                            style: TextStyle(
                              color: isSel
                                  ? Colors.white
                                  : AppColors.textSecondary,
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
                  _selectedCategory == 'All' ? 'All Places' : _selectedCategory,
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: AppColors.textPrimary,
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
                    '${filtered.length} places',
                    style: const TextStyle(
                      color: AppColors.primary,
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
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No places found',
                        style: AppTextStyles.sectionTitle.copyWith(
                          color: AppColors.textPrimary,
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
                color: AppColors.textSecondary,
                secondaryColor: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No results for "$_searchQuery"',
              style: AppTextStyles.sectionTitle.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try a different name or category',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
            '${results.length} results for "$_searchQuery"',
            style: const TextStyle(
              color: AppColors.textSecondary,
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
    final base = Colors.grey[300]!;
    final highlight = Colors.grey[100]!;
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
                  color: Colors.white,
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
                      color: Colors.white,
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
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.textSecondary.withValues(alpha: 0.2),
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
          Center(child: Icon(icon, color: AppColors.textPrimary, size: 22)),
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
                  border: Border.all(color: AppColors.background, width: 1.5),
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
        label: 'AI Trip',
        color: const Color(0xFF6366F1),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AiTripGeneratorScreen()),
        ),
      ),
      _QuickItem(
        icon: Icons.wb_twilight_rounded,
        label: 'Best Time',
        color: const Color(0xFFF59E0B),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BestTimeScreen()),
        ),
      ),
      _QuickItem(
        icon: Icons.map_rounded,
        label: 'Map',
        color: const Color(0xFF3B82F6),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MapViewScreen()),
        ),
      ),
      _QuickItem(
        icon: Icons.attach_money_rounded,
        label: 'Currency',
        color: const Color(0xFF14B8A6),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CurrencyConverterScreen()),
        ),
      ),
      _QuickItem(
        icon: Icons.directions_transit_rounded,
        label: 'Transport',
        color: const Color(0xFFEC4899),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PublicTransportScreen()),
        ),
      ),
      _QuickItem(
        icon: Icons.menu_book_rounded,
        label: 'Journal',
        color: const Color(0xFF8B5CF6),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const JournalScreen()),
        ),
      ),
      _QuickItem(
        icon: Icons.emoji_events_rounded,
        label: 'Ranking',
        color: AppColors.warning,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
        ),
      ),
      _QuickItem(
        icon: Icons.alt_route_rounded,
        label: 'Routes',
        color: AppColors.success,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CommunityRoutesScreen()),
        ),
      ),
      _QuickItem(
        icon: Icons.cloud_off_rounded,
        label: 'Offline',
        color: const Color(0xFF7C3AED),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OfflineModeScreen()),
        ),
      ),
      _QuickItem(
        icon: Icons.notifications_active_rounded,
        label: 'Nearby',
        color: AppColors.accent,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GeofencingSettingsScreen()),
        ),
      ),
      _QuickItem(
        icon: Icons.chat_bubble_rounded,
        label: 'Live Chat',
        color: const Color(0xFF10B981),
        onTap: () {
          final first = context.read<PlaceProvider>().places.first;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => LiveChatScreen(place: first)),
          );
        },
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
                'Discover',
                style: AppTextStyles.sectionTitle.copyWith(
                  color: AppColors.textPrimary,
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
              mainAxisSpacing: 8, // ????? ??????? ??? ?????? ???
              crossAxisSpacing: 12,
              childAspectRatio:
                  1.4, // ????? ????? ?? ???? ???? ???????? ?????? ??????
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
            item.label,
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
          color: active ? color : AppColors.cardBackground,
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
              label,
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