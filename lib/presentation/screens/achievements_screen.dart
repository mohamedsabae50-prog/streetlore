import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../data/achievement_catalog.dart';
import '../../l10n/app_strings.dart';
import '../../logic/achievement_provider.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        title: const Text(
          'Achievements',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        backgroundColor: context.bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.textPri),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<AchievementProvider>(
        builder: (context, ach, _) {
          final unlocked = ach.totalUnlocked;
          final total = ach.totalAvailable;
          final points = ach.totalPointsEarned;
          final ratio = ach.completionRatio;

          final byCategory = <AchievementCategory, List<AchievementDefinition>>{};
          for (final def in AchievementCatalog.all) {
            byCategory.putIfAbsent(def.category, () => []).add(def);
          }

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _Header(
                  unlocked: unlocked,
                  total: total,
                  points: points,
                  ratio: ratio,
                ),
              ),
              for (final entry in byCategory.entries) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Row(
                      children: [
                        Icon(
                          _categoryIcon(entry.key),
                          color: context.textSec,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _categoryLabel(context, entry.key),
                          style: TextStyle(
                            color: context.textPri,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${entry.value.where((d) => ach.progressFor(d.id).unlocked).length}/${entry.value.length}',
                          style: TextStyle(
                            color: context.textSec,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.78,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final def = entry.value[i];
                        return _AchievementTile(
                          definition: def,
                          progress: ach.progressFor(def.id),
                        );
                      },
                      childCount: entry.value.length,
                    ),
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
    );
  }

  IconData _categoryIcon(AchievementCategory cat) {
    switch (cat) {
      case AchievementCategory.exploration:
        return Icons.explore_rounded;
      case AchievementCategory.culture:
        return Icons.museum_rounded;
      case AchievementCategory.food:
        return Icons.restaurant_rounded;
      case AchievementCategory.social:
        return Icons.people_rounded;
      case AchievementCategory.streak:
        return Icons.local_fire_department_rounded;
      case AchievementCategory.hidden:
        return Icons.diamond_rounded;
      case AchievementCategory.special:
        return Icons.star_rounded;
    }
  }

  String _categoryLabel(BuildContext context, AchievementCategory cat) {
    switch (cat) {
      case AchievementCategory.exploration:
        return 'Exploration';
      case AchievementCategory.culture:
        return 'Culture';
      case AchievementCategory.food:
        return 'Food';
      case AchievementCategory.social:
        return 'Social';
      case AchievementCategory.streak:
        return 'Streaks';
      case AchievementCategory.hidden:
        return 'Hidden Gems';
      case AchievementCategory.special:
        return 'Special';
    }
  }
}

class _Header extends StatelessWidget {
  final int unlocked;
  final int total;
  final int points;
  final double ratio;
  const _Header({
    required this.unlocked,
    required this.total,
    required this.points,
    required this.ratio,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFB347), Color(0xFFFF7E5F), Color(0xFFE91E63)],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF7E5F).withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Collection',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      Text(
                        '$unlocked / $total unlocked',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$points',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'XP',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 10,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(ratio * 100).round()}% complete',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final AchievementDefinition definition;
  final AchievementProgress progress;
  const _AchievementTile({
    required this.definition,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final tierColor = AchievementCatalog.tierColor(definition.tier);
    final unlocked = progress.unlocked;
    final ratio = progress.ratio;

    return GestureDetector(
      onTap: () => _showDetails(context),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: unlocked
                ? tierColor.withValues(alpha: 0.5)
                : context.textSec.withValues(alpha: 0.12),
            width: unlocked ? 1.5 : 1,
          ),
          boxShadow: unlocked
              ? [
                  BoxShadow(
                    color: tierColor.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: unlocked
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              definition.color,
                              definition.color.withValues(alpha: 0.7),
                            ],
                          )
                        : null,
                    color: unlocked ? null : context.bgAlt,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: unlocked
                        ? [
                            BoxShadow(
                              color: definition.color.withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    definition.icon,
                    color: unlocked ? Colors.white : context.textSec,
                    size: 28,
                  ),
                ),
                if (!unlocked)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: context.cardColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_rounded,
                        size: 14,
                        color: context.textSec,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _name(context, definition),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.textPri,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _desc(context, definition),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.textSec,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
            const Spacer(),
            if (!unlocked) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 5,
                  backgroundColor: context.bgAlt,
                  valueColor:
                      AlwaysStoppedAnimation(definition.color),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${progress.current}/${definition.target}',
                style: TextStyle(
                  color: context.textSec,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bolt_rounded,
                    size: 12,
                    color: tierColor,
                  ),
                  Text(
                    '+${definition.points} XP',
                    style: TextStyle(
                      color: tierColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => _AchievementDetailsSheet(
        definition: definition,
        progress: progress,
      ),
    );
  }

  String _name(BuildContext context, AchievementDefinition def) {
    final tr = context.tr(def.nameKey);
    if (tr == def.nameKey) {
      switch (def.id) {
        case 'first_steps':
          return 'First Steps';
        case 'explorer_5':
          return 'Curious';
        case 'explorer_10':
          return 'Adventurer';
        case 'explorer_25':
          return 'Pathfinder';
        case 'lorekeeper':
          return 'Lorekeeper';
        case 'culture_buff':
          return 'Culture Buff';
        case 'history_nerd':
          return 'History Nerd';
        case 'foodie':
          return 'Foodie';
        case 'gourmet':
          return 'Gourmet';
        case 'shopaholic':
          return 'Shopaholic';
        case 'spiritual_seeker':
          return 'Spiritual Seeker';
        case 'pilgrim':
          return 'Pilgrim';
        case 'streak_3':
          return 'Warming Up';
        case 'streak_7':
          return 'On Fire';
        case 'streak_30':
          return 'Unstoppable';
        case 'streak_100':
          return 'Legendary';
        case 'hidden_gem_hunter':
          return 'Gem Hunter';
        case 'reviewer':
          return 'Reviewer';
        case 'critic':
          return 'Critic';
        case 'photographer':
          return 'Photographer';
        case 'influencer':
          return 'Influencer';
        case 'early_bird':
          return 'Early Bird';
        case 'night_owl':
          return 'Night Owl';
        case 'completionist':
          return 'Completionist';
      }
    }
    return tr;
  }

  String _desc(BuildContext context, AchievementDefinition def) {
    final tr = context.tr(def.descKey);
    if (tr == def.descKey) {
      return '${def.target} actions needed';
    }
    return tr;
  }
}

class _AchievementDetailsSheet extends StatelessWidget {
  final AchievementDefinition definition;
  final AchievementProgress progress;
  const _AchievementDetailsSheet({
    required this.definition,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final tierColor = AchievementCatalog.tierColor(definition.tier);
    final unlocked = progress.unlocked;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.textSec.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              gradient: unlocked
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        definition.color,
                        definition.color.withValues(alpha: 0.7),
                      ],
                    )
                  : null,
              color: unlocked ? null : context.bgAlt,
              borderRadius: BorderRadius.circular(24),
              boxShadow: unlocked
                  ? [
                      BoxShadow(
                        color: definition.color.withValues(alpha: 0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              definition.icon,
              color: unlocked ? Colors.white : context.textSec,
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _name(context, definition),
            style: TextStyle(
              color: context.textPri,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: tierColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${AchievementCatalog.tierName(definition.tier)} · +${definition.points} XP',
              style: TextStyle(
                color: tierColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _desc(context, definition),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.textSec,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          if (unlocked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.check_circle_rounded,
                      color: Color(0xFF22C55E), size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Unlocked',
                    style: TextStyle(
                      color: Color(0xFF22C55E),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress.ratio,
                minHeight: 10,
                backgroundColor: context.bgAlt,
                valueColor: AlwaysStoppedAnimation(definition.color),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${progress.current} / ${definition.target}',
              style: TextStyle(
                color: context.textSec,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _name(BuildContext context, AchievementDefinition def) {
    return context.tr(def.nameKey) == def.nameKey
        ? _fallbackName(def.id)
        : context.tr(def.nameKey);
  }

  String _desc(BuildContext context, AchievementDefinition def) {
    return context.tr(def.descKey) == def.descKey
        ? '${def.target} actions needed'
        : context.tr(def.descKey);
  }

  String _fallbackName(String id) {
    switch (id) {
      case 'first_steps':
        return 'First Steps';
      case 'explorer_5':
        return 'Curious';
      case 'explorer_10':
        return 'Adventurer';
      case 'explorer_25':
        return 'Pathfinder';
      case 'lorekeeper':
        return 'Lorekeeper';
      case 'culture_buff':
        return 'Culture Buff';
      case 'history_nerd':
        return 'History Nerd';
      case 'foodie':
        return 'Foodie';
      case 'gourmet':
        return 'Gourmet';
      case 'shopaholic':
        return 'Shopaholic';
      case 'spiritual_seeker':
        return 'Spiritual Seeker';
      case 'pilgrim':
        return 'Pilgrim';
      case 'streak_3':
        return 'Warming Up';
      case 'streak_7':
        return 'On Fire';
      case 'streak_30':
        return 'Unstoppable';
      case 'streak_100':
        return 'Legendary';
      case 'hidden_gem_hunter':
        return 'Gem Hunter';
      case 'reviewer':
        return 'Reviewer';
      case 'critic':
        return 'Critic';
      case 'photographer':
        return 'Photographer';
      case 'influencer':
        return 'Influencer';
      case 'early_bird':
        return 'Early Bird';
      case 'night_owl':
        return 'Night Owl';
      case 'completionist':
        return 'Completionist';
    }
    return id;
  }
}
