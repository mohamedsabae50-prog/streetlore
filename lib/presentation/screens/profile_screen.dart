import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/animations/app_animations.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/animated_counter.dart';
import '../../core/widgets/animated_icons.dart';
import '../../logic/place_provider.dart';
import '../../logic/theme_provider.dart';
import '../../logic/auth_provider.dart';
import '../../logic/locale_provider.dart';
import '../../logic/streak_provider.dart';
import 'login_screen.dart';
import 'emergency_screen.dart';
import 'map_view_screen.dart';
import 'currency_converter_screen.dart';
import 'public_transport_screen.dart';
import 'journal_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeP = context.watch<ThemeProvider>();
    final placeP = context.watch<PlaceProvider>();

    return Scaffold(
      backgroundColor: context.bgColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(32)),
              ),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 20,
                bottom: 32,
                left: 24,
                right: 24,
              ),
              child: Column(
                children: [
                  
                  Stack(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.2),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 3,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            auth.userName.isNotEmpty
                                ? auth.userName[0].toUpperCase()
                                : 'E',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        auth.userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  
                  const SizedBox(
                    width: 40,
                    height: 40,
                    child: AnimatedLottieIcon(
                      animation: LottieAnimations.trophy,
                      size: 40,
                      color: AppColors.warning,
                      secondaryColor: AppColors.goldLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    auth.userEmail,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),

                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _Stat(
                          label: 'Saved',
                          numericValue: placeP.savedPlaces.length,
                          icon: Icons.bookmark_rounded,
                          delayMs: 200,
                        ),
                        Container(
                            width: 1,
                            height: 36,
                            color: Colors.white.withValues(alpha: 0.2)),
                        _Stat(
                          label: 'Explored',
                          numericValue: MockPlaceVisits.count,
                          icon: Icons.explore_rounded,
                          delayMs: 320,
                        ),
                        Container(
                            width: 1,
                            height: 36,
                            color: Colors.white.withValues(alpha: 0.2)),
                        _Stat(
                          label: 'Tours',
                          textValue: 'All',
                          icon: Icons.map_rounded,
                          delayMs: 440,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.celebration_rounded, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Everything is free',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'All tours, places & guides are unlocked for everyone.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
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

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Consumer<StreakProvider>(
                builder: (context, streak, _) {
                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFB923C), Color(0xFFEF4444)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.local_fire_department_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                streak.currentStreak == 0
                                    ? 'Start your streak'
                                    : '${streak.currentStreak} day${streak.currentStreak == 1 ? '' : 's'} streak',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                streak.longestStreak > 0
                                    ? 'Best: ${streak.longestStreak} · ${streak.totalVisitDays} day${streak.totalVisitDays == 1 ? '' : 's'} total'
                                    : 'Check in at any place to begin',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: Text('App Settings',
                  style: AppTextStyles.sectionTitle
                      .copyWith(color: context.textPri)),
            ),
          ),

          SliverToBoxAdapter(
            child: FadeInUp(
              delay: const Duration(milliseconds: 200),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _Card(children: [
                  _ToggleTile(
                    icon: Icons.dark_mode_rounded,
                    title: 'Dark Mode',
                    subtitle: themeP.isDark ? 'Dark theme enabled' : 'Light theme active',
                    color: const Color(0xFF6366F1),
                    value: themeP.isDark,
                    onChanged: (_) {
                      HapticFeedback.lightImpact();
                      context.read<ThemeProvider>().toggleTheme();
                    },
                  ),
                  _Div(),
                  _ToggleTile(
                    icon: Icons.notifications_rounded,
                    title: 'Push Notifications',
                    subtitle: 'Get tips and discoveries',
                    color: AppColors.accent,
                    value: true,
                    onChanged: (_) {},
                  ),
                  _Div(),
                  _ToggleTile(
                    icon: Icons.location_on_rounded,
                    title: 'Location Services',
                    subtitle: 'Used for nearby recommendations',
                    color: AppColors.success,
                    value: true,
                    onChanged: (_) {},
                  ),
                  _Div(),
                  Consumer<LocaleProvider>(
                    builder: (context, lp, _) {
                      return _ToggleTile(
                        icon: Icons.translate_rounded,
                        title: 'Language',
                        subtitle: lp.isArabic ? 'العربية' : 'English',
                        color: const Color(0xFF0EA5E9),
                        value: lp.isArabic,
                        onChanged: (_) async {
                          HapticFeedback.lightImpact();
                          await lp.toggle();
                        },
                      );
                    },
                  ),
                ]),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: Text('Data & Privacy',
                  style: AppTextStyles.sectionTitle
                      .copyWith(color: context.textPri)),
            ),
          ),

          SliverToBoxAdapter(
            child: FadeInUp(
              delay: const Duration(milliseconds: 320),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _Card(children: [
                  _ActionTile(
                    icon: Icons.delete_outline_rounded,
                    title: 'Clear Saved Places',
                    subtitle:
                        '${placeP.savedPlaces.length} places in your collection',
                    color: AppColors.error,
                    isDestructive: true,
                    onTap: () => _showClearDialog(context, placeP),
                  ),
                  _Div(),
                  _ActionTile(
                    icon: Icons.download_outlined,
                    title: 'Export My Data',
                    subtitle: 'Download your saved collection',
                    color: AppColors.primary,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Export feature coming soon!')),
                      );
                    },
                  ),
                ]),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: Text('About',
                  style: AppTextStyles.sectionTitle
                      .copyWith(color: context.textPri)),
            ),
          ),

          SliverToBoxAdapter(
            child: FadeInUp(
              delay: const Duration(milliseconds: 440),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _Card(children: [
                  _ActionTile(
                    icon: Icons.health_and_safety_rounded,
                    title: 'Emergency Info',
                    subtitle: 'Hospitals, embassies, hotlines',
                    color: const Color(0xFFEF4444),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EmergencyScreen(),
                        ),
                      );
                    },
                  ),
                  _Div(),
                  _ActionTile(
                    icon: Icons.map_rounded,
                    title: 'Map View',
                    subtitle: 'All 42 places on interactive map',
                    color: const Color(0xFF3B82F6),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MapViewScreen()),
                      );
                    },
                  ),
                  _Div(),
                  _ActionTile(
                    icon: Icons.attach_money_rounded,
                    title: 'Currency Converter',
                    subtitle: 'EGP ↔ USD, EUR, GBP, SAR + more',
                    color: const Color(0xFF14B8A6),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CurrencyConverterScreen(),
                        ),
                      );
                    },
                  ),
                  _Div(),
                  _ActionTile(
                    icon: Icons.directions_transit_rounded,
                    title: 'Public Transport',
                    subtitle: 'Trams, buses, taxis in Alexandria',
                    color: const Color(0xFFEC4899),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PublicTransportScreen(),
                        ),
                      );
                    },
                  ),
                  _Div(),
                  _ActionTile(
                    icon: Icons.menu_book_rounded,
                    title: 'Travel Journal',
                    subtitle: 'Save memories, notes & photos',
                    color: const Color(0xFF8B5CF6),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const JournalScreen()),
                      );
                    },
                  ),
                  _Div(),
                  _ActionTile(
                    icon: Icons.help_outline_rounded,
                    title: 'Help Center',
                    subtitle: 'FAQs and support',
                    color: const Color(0xFF0EA5E9),
                    onTap: () => _showHelp(context),
                  ),
                  _Div(),
                  _ActionTile(
                    icon: Icons.star_outline_rounded,
                    title: 'Rate Streetlore',
                    subtitle: 'Share your experience',
                    color: AppColors.ratingGold,
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Thank you for your support! ')),
                    ),
                  ),
                  _Div(),
                  _ActionTile(
                    icon: Icons.info_outline_rounded,
                    title: 'About Streetlore',
                    subtitle: 'Version 2.0.0',
                    color: context.textSec,
                    onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'Streetlore',
                    applicationVersion: '2.0.0',
                    applicationIcon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.explore_rounded,
                          size: 28, color: Colors.white),
                    ),
                  ),
                ),
              ]),
              ),
            ),
          ),

          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(
                      color: AppColors.error.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  minimumSize: const Size(double.infinity, 52),
                ),
                onPressed: () => _showSignOutDialog(context),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded,
                        size: 18, color: AppColors.error),
                    const SizedBox(width: 8),
                    Text(
                      'Sign Out',
                      style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardColor,
        title: Text('Sign Out?',
            style: TextStyle(
                color: context.textPri, fontWeight: FontWeight.w800)),
        content: Text(
          'Are you sure you want to sign out? Your saved places will be preserved.',
          style: TextStyle(color: context.textSec, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: context.textSec)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AuthProvider>().signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                PageRouteBuilder(
                  pageBuilder: (_, a, __) => const LoginScreen(),
                  transitionDuration: const Duration(milliseconds: 500),
                  transitionsBuilder: (_, a, __, child) =>
                      FadeTransition(opacity: a, child: child),
                ),
                (route) => false,
              );
            },
            child: const Text('Sign Out',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showClearDialog(BuildContext context, PlaceProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardColor,
        title: Text('Clear All Saved?',
            style: TextStyle(
                color: context.textPri, fontWeight: FontWeight.w800)),
        content: Text(
          'This will permanently remove all saved places. This cannot be undone.',
          style: TextStyle(color: context.textSec, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: context.textSec)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              provider.clearAllSaved();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('All saved places cleared.'),
                    backgroundColor: AppColors.error),
              );
            },
            child: const Text('Clear',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardColor,
        title: Text('Help Center',
            style: TextStyle(
                color: context.textPri, fontWeight: FontWeight.w800)),
        content: Text(
          'For support, contact us at:\nsupport@streetlore.com\n\nWe reply within 24 hours.',
          style: TextStyle(
              color: context.textSec, fontSize: 14, height: 1.6),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class MockPlaceVisits {
  static const int count = 7;
}

class _Stat extends StatelessWidget {
  final String label;
  final int? numericValue;
  final String? textValue;
  final IconData icon;
  final int delayMs;
  const _Stat({
    required this.label,
    required this.icon,
    this.numericValue,
    this.textValue,
    this.delayMs = 0,
  });

  @override
  Widget build(BuildContext context) {
    return FadeInUp(
      delay: Duration(milliseconds: delayMs),
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(height: 4),
          if (numericValue != null)
            AnimatedCounter(
              value: numericValue!,
              duration: const Duration(milliseconds: 1200),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800),
            )
          else
            Text(textValue ?? '',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 11)),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: context.textPri)),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12, color: context.textSec)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: color,
            activeTrackColor: color.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final bool isDestructive;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.isDestructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isDestructive
                              ? color
                              : context.textPri)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12, color: context.textSec)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: context.hintColor, size: 20),
          ],
        ),
      ),
    );
  }
}

class _Div extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
        height: 1, indent: 68, endIndent: 16, color: context.dividerColor);
  }
}
