import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/animations/app_animations.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/animated_icons.dart';
import '../../core/widgets/confetti_overlay.dart';
import '../../data/achievement_catalog.dart';
import '../../data/models/gamification_stats.dart';
import '../../l10n/app_strings.dart';
import '../../logic/gamification_provider.dart';
import '../../logic/leaderboard_provider.dart';
import '../../core/services/supabase_service.dart';
import 'user_profile_screen.dart';
import '../widgets/monthly_pro_reward_banner.dart';

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

  int? _computeMyRank(
    List<CityLeaderboardEntry> entries,
    GamificationStats mine,
  ) {
    final index = entries.indexWhere(
      (entry) => entry.stats.userId == mine.userId,
    );
    return index < 0 ? null : index + 1;
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
      backgroundColor: context.bgColor,
      body: Stack(
        children: [
          SafeArea(
            child: Consumer2<LeaderboardProvider, GamificationProvider>(
              builder: (context, lb, g, _) {
                final entries = lb.entries;
                final myStats = g.stats;
                final myRank = _computeMyRank(entries, myStats);
                CityLeaderboardEntry? myStanding;
                for (final entry in entries) {
                  if (entry.stats.userId == myStats.userId) {
                    myStanding = entry;
                    break;
                  }
                }
                if (myRank != null) {
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _maybeCelebrate(myRank, myStats.level),
                  );
                }

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverAppBar(
                      floating: true,
                      backgroundColor: context.bgColor,
                      elevation: 0,
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('lb_city_title'),
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textSec,
                            ),
                          ),
                          Text(
                            context.tr('lb_title'),
                            style: AppTextStyles.screenTitle.copyWith(
                              color: context.textPri,
                            ),
                          ),
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
                    const SliverToBoxAdapter(child: MonthlyProRewardBanner()),
                    SliverToBoxAdapter(
                      child: _MyCard(
                        stats: myStats,
                        rank: myRank,
                        score: myStanding == null
                            ? null
                            : _metricValue(myStanding, lb.metric),
                        metric: lb.metric,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _LeaderboardFilters(provider: lb),
                    ),
                    if (lb.isLoading)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (lb.error != null)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  lb.error!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: context.textSec),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () => lb.load(),
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: Text(context.tr('lb_try_again')),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else if (entries.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(
                            context.tr('lb_empty'),
                            style: TextStyle(color: context.textSec),
                          ),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => FadeInUp(
                            delay: Duration(milliseconds: 80 * i + 200),
                            offsetY: 30,
                            child: _Row(
                              rank: i + 1,
                              entry: entries[i],
                              metric: lb.metric,
                            ),
                          ),
                          childCount: entries.length,
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                );
              },
            ),
          ),

          Positioned.fill(child: ConfettiOverlay(controller: _confetti)),
        ],
      ),
    );
  }
}

class _LeaderboardFilters extends StatelessWidget {
  const _LeaderboardFilters({required this.provider});

  final LeaderboardProvider provider;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final period in LeaderboardPeriod.values)
                ChoiceChip(
                  label: Text(context.tr(_periodKey(period))),
                  selected: provider.period == period,
                  onSelected: (selected) {
                    if (selected) provider.load(period: period);
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final metric in LeaderboardMetric.values)
                ChoiceChip(
                  label: Text(context.tr(_metricKey(metric))),
                  selected: provider.metric == metric,
                  onSelected: (selected) {
                    if (selected) provider.load(metric: metric);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _periodKey(LeaderboardPeriod period) {
    switch (period) {
      case LeaderboardPeriod.week:
        return 'lb_period_week';
      case LeaderboardPeriod.month:
        return 'lb_period_month';
      case LeaderboardPeriod.allTime:
        return 'lb_period_all_time';
    }
  }

  String _metricKey(LeaderboardMetric metric) {
    switch (metric) {
      case LeaderboardMetric.checkIns:
        return 'lb_metric_checkins';
      case LeaderboardMetric.longestStreak:
        return 'lb_metric_streak';
      case LeaderboardMetric.hiddenGems:
        return 'lb_metric_gems';
    }
  }
}

String _metricKey(LeaderboardMetric metric) {
  switch (metric) {
    case LeaderboardMetric.checkIns:
      return 'lb_stat_checkins';
    case LeaderboardMetric.longestStreak:
      return 'lb_stat_streak';
    case LeaderboardMetric.hiddenGems:
      return 'lb_stat_gems';
  }
}

String _metricLabel(BuildContext context, LeaderboardMetric metric) =>
    context.tr(_metricKey(metric));

int _metricValue(CityLeaderboardEntry entry, LeaderboardMetric metric) {
  switch (metric) {
    case LeaderboardMetric.checkIns:
      return entry.checkIns;
    case LeaderboardMetric.longestStreak:
      return entry.longestStreak;
    case LeaderboardMetric.hiddenGems:
      return entry.hiddenGems;
  }
}

String _badgeName(BuildContext context, Badge badge) {
  final achievement = AchievementCatalog.byId(badge.id);
  if (achievement != null) return context.tr(achievement.nameKey);
  if (badge.id.startsWith('lvl_')) {
    final level = AppStrings.level(context, badge.id.substring(4));
    return context.tr('lb_badge_rank', {'level': level});
  }
  return context.tr(badge.name);
}

class _MyCard extends StatelessWidget {
  final GamificationStats stats;
  final int? rank;
  final int? score;
  final LeaderboardMetric metric;
  const _MyCard({
    required this.stats,
    required this.rank,
    required this.score,
    required this.metric,
  });

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
          Text(
            context.tr('lb_your_rank'),
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
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
                    Text(
                      stats.userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      score == null
                          ? context.tr('lb_points_level', {
                              'p': '${stats.totalPoints}',
                              'l': AppStrings.level(context, stats.level),
                            })
                          : '${score!} ${_metricLabel(context, metric)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
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
                    const Icon(
                      Icons.emoji_events_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    Text(
                      rank == null ? '—' : '#$rank',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _miniStat(
                Icons.location_on_rounded,
                '${stats.placesVisited}',
                context.tr('stat_visited'),
              ),
              const SizedBox(width: 16),
              _miniStat(
                Icons.star_rounded,
                '${stats.reviewsPosted}',
                context.tr('stat_reviews'),
              ),
            ],
          ),
          if (stats.badges.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: stats.badges
                  .map(
                    (b) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.workspace_premium,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _badgeName(context, b),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
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
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(width: 2),
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
    ],
  );
}

class _Row extends StatelessWidget {
  final int rank;
  final CityLeaderboardEntry entry;
  final LeaderboardMetric metric;
  const _Row({required this.rank, required this.entry, required this.metric});

  @override
  Widget build(BuildContext context) {
    final stats = entry.stats;
    Color? avatarColor;
    if (stats.avatarColorHex != null && stats.avatarColorHex!.isNotEmpty) {
      try {
        final hex = stats.avatarColorHex!
            .replaceFirst('#', '0xff')
            .replaceFirst('0x', '0xff');
        avatarColor = Color(int.parse(hex));
      } catch (_) {}
    }
    final isTop3 = rank <= 3;
    return InkWell(
      onTap: () => _openProfile(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isTop3
                ? AppColors.warning.withValues(alpha: 0.4)
                : context.hintColor.withValues(alpha: 0.3),
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
                    : context.hintColor.withValues(alpha: 0.18),
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
                  : Text(
                      '$rank',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: context.textSec,
                      ),
                    ),
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
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stats.userName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _StatChip(
                        value: entry.checkIns,
                        label: context.tr('lb_stat_checkins'),
                      ),
                      _StatChip(
                        value: entry.longestStreak,
                        label: context.tr('lb_stat_streak'),
                      ),
                      _StatChip(
                        value: entry.hiddenGems,
                        label: context.tr('lb_stat_gems'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_metricValue(entry, metric)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: context.textPri,
                  ),
                ),
                Text(
                  _metricLabel(context, metric),
                  style: TextStyle(color: context.textSec, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openProfile(BuildContext context) async {
    try {
      final user = await SupabaseService.instance.getSocialUser(
        entry.stats.userId,
      );
      if (user == null || !context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => UserProfileScreen(user: user)),
      );
    } catch (error, stackTrace) {
      debugPrint('LeaderboardScreen: profile load failed: $error\n$stackTrace');
    }
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: context.bgAlt,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value',
          textDirection: TextDirection.ltr,
          style: TextStyle(
            color: context.textPri,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: context.textSec, fontSize: 11)),
      ],
    ),
  );
}
