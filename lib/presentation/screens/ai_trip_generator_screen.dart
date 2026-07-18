import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/services/ai_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/animated_icons.dart';
import '../../data/models/ai_trip_plan.dart';
import '../../data/models/place_model.dart';
import '../../logic/place_provider.dart';
import '../../logic/trip_provider.dart';
import 'place_details_screen.dart';

class AiTripGeneratorScreen extends StatefulWidget {
  const AiTripGeneratorScreen({super.key});

  @override
  State<AiTripGeneratorScreen> createState() => _AiTripGeneratorScreenState();
}

class _AiTripGeneratorScreenState extends State<AiTripGeneratorScreen> {
  final _promptCtrl = TextEditingController();
  int _days = 2;
  String _budget = '\$\$';
  bool _busy = false;
  AiTripPlan? _plan;
  String? _error;

  static const _suggestions = <String>[
    'Two days in Alexandria, mid-budget, love history and seafood',
    'One relaxed day focused on cafés and the corniche',
    'Three days off the beaten path, hidden gems only',
    'A family day with kid-friendly museums and a beach',
  ];

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final prompt = _promptCtrl.text.trim();
    if (prompt.isEmpty) {
      setState(() => _error = 'Please describe what kind of trip you want.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _plan = null;
    });
    try {
      final places = context.read<PlaceProvider>().places;
      final plan = await AiService.instance.generateTrip(
        prompt: prompt,
        availablePlaces: places,
        daysHint: _days,
      );
      setState(() => _plan = plan);
    } catch (e) {
      setState(() => _error = 'Failed to generate: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AI Trip Generator'),
        actions: [
          if (!AppConfig.geminiEnabled)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'MOCK',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        physics: const BouncingScrollPhysics(),
        children: [
          
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: AnimatedLottieIcon(
                      animation: LottieAnimations.compass,
                      size: 40,
                      color: Colors.white,
                      secondaryColor: Color(0xFFA78BFA),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Powered by Gemini',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Describe your ideal Alexandria trip and we\'ll plan it.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Tell us about your trip', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 8),
          TextField(
            controller: _promptCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'e.g. two days in Alexandria, mid-budget, love history',
              filled: true,
              fillColor: AppColors.cardBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.textHint),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.textHint.withValues(alpha: 0.3)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions
                .map((s) => ActionChip(
                      label: Text(s, style: const TextStyle(fontSize: 12)),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _promptCtrl.text = s;
                      },
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _DaysPicker(value: _days, onChanged: (v) => setState(() => _days = v))),
              const SizedBox(width: 12),
              Expanded(child: _BudgetPicker(value: _budget, onChanged: (v) => setState(() => _budget = v))),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _generate,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: _busy
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome, color: Colors.white),
              label: Text(
                _busy ? 'Generating...' : 'Generate Itinerary',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!,
                      style: const TextStyle(color: AppColors.error))),
                ],
              ),
            ),
          ],
          if (_plan != null) ...[
            const SizedBox(height: 24),
            _PlanSummary(plan: _plan!),
            const SizedBox(height: 16),
            for (final day in _plan!.days) _DayCard(day: day),
            const SizedBox(height: 16),
            if (_plan!.tips.isNotEmpty) _TipsCard(tips: _plan!.tips),
          ],
        ],
      ),
    );
  }
}

class _DaysPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _DaysPicker({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.textHint.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          const Text('Days', style: TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          DropdownButton<int>(
            value: value,
            underline: const SizedBox(),
            items: const [1, 2, 3, 4, 5]
                .map((d) => DropdownMenuItem(value: d, child: Text('$d')))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}

class _BudgetPicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _BudgetPicker({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.textHint.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.payments_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          const Text('Budget', style: TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          DropdownButton<String>(
            value: value,
            underline: const SizedBox(),
            items: const [r'$', r'$$', r'$$$', r'$$$$']
                .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}

class _PlanSummary extends StatelessWidget {
  final AiTripPlan plan;
  const _PlanSummary({required this.plan});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.textHint.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(plan.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(plan.summary,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5)),
          const SizedBox(height: 12),
          Row(
            children: [
              _badge('${plan.totalDays} days'),
              const SizedBox(width: 8),
              _badge(plan.estimatedBudget),
              const SizedBox(width: 8),
              _badge('${plan.days.fold(0, (s, d) => s + d.stops.length)} stops'),
            ],
          ),
          const SizedBox(height: 16),
          Consumer<TripProvider>(
            builder: (context, trip, _) {
              return SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final ids = plan.days
                        .expand((d) => d.stops.map((s) => s.placeId))
                        .toList();
                    final places = context
                        .read<PlaceProvider>()
                        .places
                        .where((p) => ids.contains(p.id))
                        .toList();
                    for (final p in places) {
                      trip.togglePlaceInTrip(p);
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added ${places.length} places to your Trip Planner')),
                    );
                  },
                  icon: const Icon(Icons.add_road_rounded),
                  label: const Text('Add all to Trip Planner'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _badge(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            )),
      );
}

class _DayCard extends StatelessWidget {
  final AiTripDay day;
  const _DayCard({required this.day});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.textHint.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text('${day.dayNumber}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(day.theme,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final s in day.stops) _StopTile(stop: s),
        ],
      ),
    );
  }
}

class _StopTile extends StatelessWidget {
  final AiTripStop stop;
  const _StopTile({required this.stop});

  PlaceModel? _resolvePlace(List<PlaceModel> places, String id) {
    for (final p in places) {
      if (p.id == id) return p;
    }
    return places.isNotEmpty ? places.first : null;
  }
  @override
  Widget build(BuildContext context) {
    final places = context.watch<PlaceProvider>().places;
    final place = _resolvePlace(places, stop.placeId);
    if (place == null) {
      return const SizedBox.shrink();
    }
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PlaceDetailsScreen(place: place)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 6,
              margin: const EdgeInsets.only(top: 6, right: 12),
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(place.name,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                      Text(stop.suggestedTime,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                  if (stop.note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(stop.note,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipsCard extends StatelessWidget {
  final List<String> tips;
  const _TipsCard({required this.tips});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Local tips',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final t in tips) ...[
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(
                padding: EdgeInsets.only(top: 2, right: 6),
                child: Icon(Icons.lightbulb_rounded,
                    size: 14, color: AppColors.warning),
              ),
              Expanded(child: Text(t, style: const TextStyle(fontSize: 13, height: 1.5))),
            ]),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}
