import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/place_model.dart';
import '../../logic/place_provider.dart';
import 'place_details_screen.dart';

class MapViewScreen extends StatefulWidget {
  const MapViewScreen({super.key});

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> {
  final MapController _mapController = MapController();
  String? _selectedCategory;
  PlaceModel? _selectedPlace;

  static const _alexCenter = LatLng(31.2001, 29.9187);

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'Historical': return Icons.account_balance_rounded;
      case 'Culture': return Icons.museum_rounded;
      case 'Nature': return Icons.park_rounded;
      case 'Food': return Icons.restaurant_rounded;
      case 'Shopping': return Icons.shopping_bag_rounded;
      case 'Mosques': return Icons.mosque_rounded;
      case 'Churches': return Icons.church_rounded;
      case 'Streets': return Icons.signpost_rounded;
      default: return Icons.location_on_rounded;
    }
  }

  Color _colorForCategory(String category) {
    switch (category) {
      case 'Historical': return const Color(0xFF8B5CF6);
      case 'Culture': return const Color(0xFFEC4899);
      case 'Nature': return const Color(0xFF10B981);
      case 'Food': return const Color(0xFFF59E0B);
      case 'Shopping': return const Color(0xFF3B82F6);
      case 'Mosques': return const Color(0xFF14B8A6);
      case 'Churches': return const Color(0xFFF97316);
      case 'Streets': return const Color(0xFF6366F1);
      default: return AppColors.primary;
    }
  }

  List<PlaceModel> _filtered(List<PlaceModel> all) {
    if (_selectedCategory == null) return all;
    return all.where((p) => p.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    final places = context.watch<PlaceProvider>().places;
    final visible = _filtered(places);

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _alexCenter,
              initialZoom: 12,
              minZoom: 5,
              maxZoom: 18,
              onTap: (_, __) => setState(() => _selectedPlace = null),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.streetlore.app',
                maxZoom: 19,
              ),
              MarkerLayer(
                markers: [
                  for (final p in visible)
                    Marker(
                      point: LatLng(p.lat, p.lng),
                      width: 44,
                      height: 44,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedPlace = p);
                          _mapController.move(LatLng(p.lat, p.lng), 14);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: _colorForCategory(p.category),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _colorForCategory(p.category).withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: Icon(
                            _iconForCategory(p.category),
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  IconButton.filled(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        'Alexandria Map · ${visible.length} places',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_selectedPlace != null)
            Positioned(
              left: 16, right: 16, bottom: 16,
              child: _SelectedPlaceCard(
                place: _selectedPlace!,
                color: _colorForCategory(_selectedPlace!.category),
                icon: _iconForCategory(_selectedPlace!.category),
                onClose: () => setState(() => _selectedPlace = null),
                onOpen: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlaceDetailsScreen(place: _selectedPlace!),
                    ),
                  );
                },
              ),
            ),
          Positioned(
            left: 0, right: 0, bottom: _selectedPlace != null ? 110 : 16,
            child: _CategoryFilter(
              selected: _selectedCategory,
              onSelect: (cat) => setState(() => _selectedCategory = cat),
              colorOf: _colorForCategory,
              iconOf: _iconForCategory,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedPlaceCard extends StatelessWidget {
  final PlaceModel place;
  final Color color;
  final IconData icon;
  final VoidCallback onClose;
  final VoidCallback onOpen;

  const _SelectedPlaceCard({
    required this.place,
    required this.color,
    required this.icon,
    required this.onClose,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  place.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      place.category,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.star_rounded, size: 12, color: Color(0xFFFBBF24)),
                    const SizedBox(width: 2),
                    Text(
                      place.rating.toString(),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onOpen,
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            color: color,
            tooltip: 'Open details',
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 18),
            color: AppColors.textHint,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onSelect;
  final Color Function(String) colorOf;
  final IconData Function(String) iconOf;

  const _CategoryFilter({
    required this.selected,
    required this.onSelect,
    required this.colorOf,
    required this.iconOf,
  });

  @override
  Widget build(BuildContext context) {
    const cats = ['All', 'Historical', 'Culture', 'Nature', 'Food', 'Mosques', 'Churches'];
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        itemCount: cats.length,
        itemBuilder: (context, i) {
          final cat = cats[i];
          final isAll = cat == 'All';
          final isSel = (isAll && selected == null) || cat == selected;
          final color = isAll ? AppColors.primary : colorOf(cat);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSel,
              onSelected: (_) => onSelect(isAll ? null : cat),
              avatar: Icon(
                isAll ? Icons.apps_rounded : iconOf(cat),
                size: 16,
                color: isSel ? Colors.white : color,
              ),
              label: Text(
                cat,
                style: TextStyle(
                  color: isSel ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              backgroundColor: Colors.white,
              selectedColor: color,
              checkmarkColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSel ? color : Colors.white,
                  width: 1.5,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
