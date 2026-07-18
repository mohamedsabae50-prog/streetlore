import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/animations/app_animations.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/animated_counter.dart';
import '../../core/widgets/animated_icons.dart';
import '../../core/widgets/confetti_overlay.dart';
import '../../data/models/gamification_stats.dart';
import '../../logic/gamification_provider.dart';
import '../../logic/leaderboard_provider.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final ConfettiController _confetti = ConfettiController();
  int? _previousMyRank;
  String? _previousLevel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LeaderboardProvider>().load();
    });
  }

  int _computeMyRank(List<GamificationStats> entries, GamificationStats mine) {
    
    
    final better = entries.where((e) => e.totalPoints > mine.totalPoints).length;
    return better + 1;
  }

  void _maybeCelebrate(int newRank, String newLevel) {
    if (_previousMyRank == null) {
      _previousMyRank = newRank;
      _previousLevel = newLevel;
      return;
    }
    final leveledUp = _previousLevel != null && _previousLevel != newLevel;
    final rankedUp = newRank < (_previousMyRank ?? newRank);
    if (leveledUp || rankedUp) {
      HapticFeedback.heavyImpact();
      _confetti.play();
    }
    _previousMyRank = newRank;
    _previousLevel = newLevel;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Consumer2<LeaderboardProvider, GamificationProvider>(
            builder: (context, lb, g, _) {
              final entries = lb.entries;
              final myStats = g.stats;
              final myRank = _computeMyRank(entries, myStats);
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _maybeCelebrate(myRank, myStats.level),
              );
              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    floating: true,
                    backgroundColor: AppColors.background,
                    elevation: 0,
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Most travelled in Alexandria',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                        Text('Leaderboard', style: AppTextStyles.screenTitle),
                      ],
                    ),
                    actions: [
                      
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: AnimatedLottieIcon(
                            animation: LottieAnimations.trophy,
                            size: 40,
                            color: AppColors.warning,
                            secondaryColor: AppColors.goldLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SliverToBoxAdapter(
                    child: _MyCard(stats: myStats, rank: myRank),
                  ),
                  if (lb.isLoading)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (entries.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('No leaderboard data yet')),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => FadeInUp(
                          delay: Duration(milliseconds: 80 * i + 200),
                          offsetY: 30,
                          child: _Row(rank: i + 1, stats: entries[i]),
                        ),
                        childCount: entries.length,
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              );
            },
          ),
          
          Positioned.fill(
            child: ConfettiOverlay(controller: _confetti),
          ),
        ],
      ),
    );
  }
}

class _MyCard extends StatelessWidget {
  final GamificationStats stats;
  final int rank;
  const _MyCard({required this.stats, required this.rank});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF1E3A5F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('YOUR RANK',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              )),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  stats.userName.isNotEmpty
                      ? stats.userName[0].toUpperCase()
                      : 'Y',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stats.userName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    AnimatedCounter(
                      value: stats.totalPoints,
                      suffix: ' points · ${stats.level}',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.warning, AppColors.goldLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.warning.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.emoji_events_rounded,
                        color: Colors.white, size: 18),
                    Text('#$rank',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        )),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _miniStat(Icons.location_on_rounded, '${stats.placesVisited}', 'Visited'),
              const SizedBox(width: 16),
              _miniStat(Icons.star_rounded, '${stats.reviewsPosted}', 'Reviews'),
              const SizedBox(width: 16),
              _miniStat(Icons.alt_route_rounded, '${stats.routesCreated}', 'Routes'),
            ],
          ),
          if (stats.badges.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: stats.badges
                  .map((b) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.workspace_premium,
                              color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text(b.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              )),
                        ]),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String value, String label) => Row(
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(width: 2),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      );
}

class _Row extends StatelessWidget {
  final int rank;
  final GamificationStats stats;
  const _Row({required this.rank, required this.stats});
  @override
  Widget build(BuildContext context) {
    Color? avatarColor;
    if (stats.avatarColorHex != null) {
      avatarColor =
          Color(int.parse(stats.avatarColorHex!.replaceFirst('0x', '0xff')));
    }
    final isTop3 = rank <= 3;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isTop3
              ? AppColors.warning.withValues(alpha: 0.4)
              : AppColors.textHint.withValues(alpha: 0.3),
        ),
        boxShadow: isTop3
            ? [
                BoxShadow(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isTop3
                  ? AppColors.warning.withValues(alpha: 0.18)
                  : AppColors.textHint.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: isTop3
                ? Icon(
                    [
                      Icons.emoji_events_rounded,
                      Icons.military_tech_rounded,
                      Icons.workspace_premium_rounded,
                    ][rank - 1],
                    color: AppColors.warning,
                    size: 20,
                  )
                : Text('$rank',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                    )),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 18,
            backgroundColor: avatarColor ?? AppColors.primary,
            child: Text(
              stats.userName.isNotEmpty
                  ? stats.userName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stats.userName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                Text(
                    '${stats.placesVisited} visited · ${stats.reviewsPosted} reviews',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedCounter(
                value: stats.totalPoints,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary)),
              Text(stats.level,
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
