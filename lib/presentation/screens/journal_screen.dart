import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/journal_entry.dart';
import '../../data/models/place_model.dart';
import '../../logic/journal_provider.dart';
import '../../logic/place_provider.dart';
import 'place_details_screen.dart';

class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Travel Journal'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: Consumer<JournalProvider>(
        builder: (context, journal, _) {
          if (journal.entries.isEmpty) {
            return _EmptyState(
              onPick: () => _showPlacePicker(context, journal),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            physics: const BouncingScrollPhysics(),
            itemCount: journal.entries.length,
            itemBuilder: (context, i) {
              final e = journal.entries[i];
              return _JournalCard(
                entry: e,
                onTap: () {
                  final p = context.read<PlaceProvider>().findById(e.placeId);
                  if (p != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PlaceDetailsScreen(place: p)),
                    );
                  }
                },
                onEdit: () => _showEditor(context, journal, e),
                onDelete: () => journal.remove(e.id),
              );
            },
          );
        },
      ),
      floatingActionButton: Consumer<JournalProvider>(
        builder: (context, journal, _) {
          return FloatingActionButton.extended(
            onPressed: () => _showPlacePicker(context, journal),
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: const Text(
              'Add memory',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
          );
        },
      ),
    );
  }

  static Future<void> _showPlacePicker(
    BuildContext context,
    JournalProvider journal,
  ) async {
    final places = context.read<PlaceProvider>().places;
    final picked = await showModalBottomSheet<PlaceModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _PlacePickerSheet(places: places);
      },
    );
    if (picked != null && context.mounted) {
      _showEditor(context, journal, null, place: picked);
    }
  }

  static Future<void> _showEditor(
    BuildContext context,
    JournalProvider journal,
    JournalEntry? existing, {
    PlaceModel? place,
  }) async {
    final place0 = place ??
        context.read<PlaceProvider>().findById(existing?.placeId ?? '');
    if (place0 == null) return;
    final result = await showModalBottomSheet<JournalEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _JournalEditorSheet(
        place: place0,
        existing: existing,
      ),
    );
    if (result != null) {
      if (existing == null) {
        await journal.add(result);
      } else {
        await journal.update(result);
      }
    }
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onPick;
  const _EmptyState({required this.onPick});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.menu_book_rounded, size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your travel journal is empty',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Save memories, photos, and notes for every place you visit.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add first memory'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JournalCard extends StatelessWidget {
  final JournalEntry entry;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _JournalCard({
    required this.entry,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  String _dateLabel(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.textHint.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.placeName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _dateLabel(entry.visitedAt),
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: List.generate(5, (i) {
                    return Icon(
                      i < entry.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 16,
                      color: const Color(0xFFFBBF24),
                    );
                  }),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: AppColors.textHint),
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            if (entry.note != null && entry.note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                entry.note!,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  height: 1.5,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlacePickerSheet extends StatefulWidget {
  final List<PlaceModel> places;
  const _PlacePickerSheet({required this.places});
  @override
  State<_PlacePickerSheet> createState() => _PlacePickerSheetState();
}

class _PlacePickerSheetState extends State<_PlacePickerSheet> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final term = _search.text.toLowerCase().trim();
    final filtered = term.isEmpty
        ? widget.places
        : widget.places.where((p) => p.name.toLowerCase().contains(term)).toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scroll) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textHint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Pick a place', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search places...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: AppColors.cardBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final p = filtered[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          p.imageUrl,
                          width: 48, height: 48, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 48, height: 48, color: AppColors.backgroundAlt,
                            child: const Icon(Icons.image_rounded, color: AppColors.textHint),
                          ),
                        ),
                      ),
                      title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(p.category),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context, p);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _JournalEditorSheet extends StatefulWidget {
  final PlaceModel place;
  final JournalEntry? existing;
  const _JournalEditorSheet({required this.place, this.existing});

  @override
  State<_JournalEditorSheet> createState() => _JournalEditorSheetState();
}

class _JournalEditorSheetState extends State<_JournalEditorSheet> {
  late TextEditingController _noteCtrl;
  late int _rating;
  late DateTime _visitedAt;

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController(text: widget.existing?.note ?? '');
    _rating = widget.existing?.rating ?? 5;
    _visitedAt = widget.existing?.visitedAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (context, scroll) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textHint,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.existing == null ? 'New memory' : 'Edit memory',
                  style: AppTextStyles.screenTitle,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.place.name,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                Text('Rating', style: AppTextStyles.sectionTitle),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(5, (i) {
                    return IconButton(
                      onPressed: () => setState(() => _rating = i + 1),
                      icon: Icon(
                        i < _rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 32,
                        color: const Color(0xFFFBBF24),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                Text('Notes', style: AppTextStyles.sectionTitle),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteCtrl,
                  maxLines: 6,
                  decoration: InputDecoration(
                    hintText: 'What did you think? What did you do? Tips for other travelers?',
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
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final entry = JournalEntry(
                        id: widget.existing?.id ?? const Uuid().v4(),
                        placeId: widget.place.id,
                        placeName: widget.place.name,
                        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
                        visitedAt: _visitedAt,
                        rating: _rating,
                      );
                      Navigator.pop(context, entry);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.check_rounded, color: Colors.white),
                    label: Text(
                      widget.existing == null ? 'Save memory' : 'Update memory',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
