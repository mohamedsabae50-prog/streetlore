import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/animations/app_animations.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/animated_icons.dart';
import '../../core/widgets/shimmer_image.dart';
import '../../data/models/place_model.dart';
import '../../data/models/user_route.dart';
import '../../logic/auth_provider.dart';
import '../../logic/community_routes_provider.dart';
import '../../logic/place_provider.dart';

class CommunityRoutesScreen extends StatefulWidget {
  const CommunityRoutesScreen({super.key});

  @override
  State<CommunityRoutesScreen> createState() => _CommunityRoutesScreenState();
}

class _CommunityRoutesScreenState extends State<CommunityRoutesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CommunityRoutesProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Community Routes'),
            const SizedBox(width: 8),
            const SizedBox(
              width: 28,
              height: 28,
              child: AnimatedLottieIcon(
                animation: LottieAnimations.route,
                size: 28,
                color: AppColors.success,
                secondaryColor: AppColors.primary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Create route',
            onPressed: _openCreator,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      body: Consumer<CommunityRoutesProvider>(
        builder: (context, prov, _) {
          if (prov.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (prov.routes.isEmpty) {
            return const Center(child: Text('No community routes yet. Be the first!'));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            physics: const BouncingScrollPhysics(),
            itemCount: prov.routes.length,
            itemBuilder: (context, i) => FadeInUp(
              delay: Duration(milliseconds: 80 * i + 200),
              offsetY: 30,
              child: _RouteCard(route: prov.routes[i]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreator,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_road_rounded, color: Colors.white),
        label: const Text('New route', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Future<void> _openCreator() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _RouteCreatorSheet(),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Route published!')),
      );
    }
  }
}

class _RouteCard extends StatelessWidget {
  final UserRoute route;
  const _RouteCard({required this.route});

  @override
  Widget build(BuildContext context) {
    final places = context.watch<PlaceProvider>().places
        .where((p) => route.placeIds.contains(p.id))
        .toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.textHint.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 130,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (places.isNotEmpty)
                  ShimmerImage(
                    imageUrl: places.first.imageUrl,
                    fit: BoxFit.cover,
                    fallbackIcon: Icons.image_not_supported_rounded,
                    fallbackColor: AppColors.textHint,
                  )
                else
                  Container(color: AppColors.backgroundAlt),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xCC0F172A)],
                    ),
                  ),
                ),
                Positioned(
                  left: 12, bottom: 12, right: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(route.title,
                          style: const TextStyle(
                            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800,
                          ),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      Text('by ${route.authorName} · ${route.placeIds.length} stops',
                          style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(route.description,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                    maxLines: 3, overflow: TextOverflow.ellipsis),
                if (route.tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: route.tags
                        .map((t) => Chip(
                              label: Text(t, style: const TextStyle(fontSize: 10)),
                              backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                              side: BorderSide.none,
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    _Action(
                      icon: Icons.favorite_rounded,
                      label: '${route.likes}',
                      onTap: () => context.read<CommunityRoutesProvider>().like(route.id),
                    ),
                    const SizedBox(width: 16),
                    _Action(icon: Icons.bookmark_outline_rounded, label: '${route.saves}', onTap: () {}),
                    const Spacer(),
                    _Action(icon: Icons.share_rounded, label: 'Share', onTap: () {}),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Action({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _RouteCreatorSheet extends StatefulWidget {
  const _RouteCreatorSheet();
  @override
  State<_RouteCreatorSheet> createState() => _RouteCreatorSheetState();
}

class _RouteCreatorSheetState extends State<_RouteCreatorSheet> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _tags = TextEditingController();
  final List<PlaceModel> _selected = [];

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (_title.text.trim().isEmpty || _selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a title and at least one place')),
      );
      return;
    }
    final auth = context.read<AuthProvider>();
    final route = UserRoute(
      id: const Uuid().v4(),
      title: _title.text.trim(),
      description: _description.text.trim(),
      authorId: auth.userEmail,
      authorName: auth.userName,
      placeIds: _selected.map((p) => p.id).toList(),
      createdAt: DateTime.now(),
      tags: _tags.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList(),
    );
    await context.read<CommunityRoutesProvider>().publish(route);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final places = context.watch<PlaceProvider>().places;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      builder: (context, scroll) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textHint,
                  borderRadius: BorderRadius.circular(2),
                )),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text('Create a route', style: AppTextStyles.screenTitle),
                    const Spacer(),
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 90),
                  children: [
                    _Field(controller: _title, label: 'Title', hint: 'Sunset at the Citadel'),
                    const SizedBox(height: 12),
                    _Field(
                      controller: _description,
                      label: 'Description',
                      hint: 'Why is this route special?',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      controller: _tags,
                      label: 'Tags (comma separated)',
                      hint: 'sunset, food, photography',
                    ),
                    const SizedBox(height: 20),
                    const Text('Choose places', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    ...places.map((p) => CheckboxListTile(
                          value: _selected.any((s) => s.id == p.id),
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selected.add(p);
                              } else {
                                _selected.removeWhere((s) => s.id == p.id);
                              }
                            });
                          },
                          title: Text(p.name),
                          subtitle: Text(p.category),
                          controlAffinity: ListTileControlAffinity.trailing,
                        )),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  border: Border(top: BorderSide(color: AppColors.textHint.withValues(alpha: 0.3))),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _publish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.publish_rounded, color: Colors.white),
                    label: const Text('Publish route',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
  });
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: AppColors.cardBackground,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}
