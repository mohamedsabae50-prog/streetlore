import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/animations/app_animations.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../logic/tour_provider.dart';
import '../../logic/auth_provider.dart';
import '../../logic/squad_provider.dart';
import '../../l10n/app_strings.dart';
import '../widgets/tour_card.dart';
import 'paywall_screen.dart';
import 'tour_details_screen.dart';
import 'squad_screen.dart';

class ToursScreen extends StatefulWidget {
  const ToursScreen({super.key});

  @override
  State<ToursScreen> createState() => _ToursScreenState();
}

class _ToursScreenState extends State<ToursScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AuthProvider>().isPro) {
      return Scaffold(
        backgroundColor: context.bgColor,
        appBar: AppBar(
          backgroundColor: context.bgColor,
          title: Text(context.tr('tours_title')),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_rounded,
                  size: 56,
                  color: AppColors.ratingGold,
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr('tour_pro_locked'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.textSec, fontSize: 15),
                ),
                const SizedBox(height: 18),
                _squadButton(context),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _openPaywall,
                  icon: const Icon(Icons.workspace_premium_rounded),
                  label: Text(context.tr('pro_title')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final filtered = context.watch<TourProvider>().tours;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: RefreshIndicator(
            onRefresh: () => context.read<TourProvider>().refresh(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverAppBar(
                  floating: true,
                  snap: true,
                  backgroundColor: context.bgColor,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  titleSpacing: 20,
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('tours_subtitle'),
                        style: TextStyle(fontSize: 12, color: context.textSec),
                      ),
                      Text(
                        context.tr('tours_title'),
                        style: AppTextStyles.screenTitle.copyWith(
                          color: context.textPri,
                        ),
                      ),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                    child: _squadButton(context),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: Text(
                      filtered.isEmpty
                          ? context.tr('no_tours')
                          : context.tr('tours_available', {
                              'n': '${filtered.length}',
                            }),
                      style: TextStyle(
                        color: context.textSec,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Text(
                          context.tr('loading_tours'),
                          style: TextStyle(color: context.textSec),
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, i) {
                      final tour = filtered[i];
                      return FadeInUp(
                        delay: Duration(milliseconds: 100 * i + 200),
                        offsetY: 30,
                        child: TourCard(
                          tour: tour,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TourDetailsScreen(tour: tour),
                              ),
                            );
                          },
                        ),
                      );
                    }, childCount: filtered.length),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openPaywall() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const PaywallScreen()),
    );
  }

  Widget _squadButton(BuildContext context) {
    final hasActiveSquad = context.watch<SquadProvider>().hasActiveSquad;
    return Card(
      margin: EdgeInsets.zero,
      color: context.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: context.borderColor),
      ),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.groups_rounded, color: AppColors.success),
        ),
        title: Text(
          hasActiveSquad
              ? context.tr('squad_active_title')
              : context.tr('squad_title'),
          style: TextStyle(color: context.textPri, fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          hasActiveSquad
              ? context.tr('squad_invite_subtitle')
              : context.tr('squad_start_subtitle'),
          style: TextStyle(color: context.textSec),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: context.textSec),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const SquadScreen()),
          );
        },
      ),
    );
  }
}
