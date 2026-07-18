import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/animated_icons.dart';
import '../../data/models/geofence_alert.dart';
import '../../data/models/place_model.dart';
import '../../logic/geofence_provider.dart';
import '../../logic/place_provider.dart';

class GeofencingSettingsScreen extends StatelessWidget {
  const GeofencingSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Geofencing Alerts')),
      body: Consumer<GeofenceProvider>(
        builder: (context, geo, _) {
          final places = context.watch<PlaceProvider>().places;
          final selectedIds = geo.alerts.map((a) => a.placeId).toSet();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            physics: const BouncingScrollPhysics(),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFFB923C)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 56,
                      height: 56,
                      child: Padding(
                        padding: EdgeInsets.all(2),
                        child: AnimatedLottieIcon(
                          animation: LottieAnimations.radar,
                          size: 52,
                          color: Colors.white,
                          secondaryColor: Color(0xFFFCD34D),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Get notified nearby',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                          SizedBox(height: 4),
                          Text('Choose the places you want alerts for - within 500m by default.',
                              style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.textHint.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(geo.isMonitoring ? Icons.gps_fixed : Icons.gps_off,
                        color: geo.isMonitoring ? AppColors.success : AppColors.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(geo.isMonitoring
                          ? 'Monitoring your location for nearby places'
                          : 'Monitoring paused'),
                    ),
                    Switch.adaptive(
                      value: geo.isMonitoring,
                      onChanged: (v) => v ? geo.startMonitoring() : geo.stopMonitoring(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('Choose places', style: AppTextStyles.sectionTitle),
              const SizedBox(height: 8),
              for (final place in places)
                _PlaceToggle(
                  place: place,
                  enabled: selectedIds.contains(place.id),
                  onToggle: () {
                    final existing = geo.alerts.firstWhere(
                      (a) => a.placeId == place.id,
                      orElse: () => GeofenceAlert(
                        placeId: place.id,
                        placeName: place.name,
                        lat: place.lat,
                        lng: place.lng,
                      ),
                    );
                    geo.toggle(existing);
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PlaceToggle extends StatelessWidget {
  final PlaceModel place;
  final bool enabled;
  final VoidCallback onToggle;
  const _PlaceToggle({required this.place, required this.enabled, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled
              ? AppColors.success.withValues(alpha: 0.4)
              : AppColors.textHint.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              place.imageUrl,
              width: 50, height: 50, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(width: 50, height: 50, color: AppColors.backgroundAlt),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(place.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text('${Geolocator.distanceBetween(0, 0, place.lat, place.lng).toStringAsFixed(0)} m from city center',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          Switch.adaptive(
            value: enabled,
            onChanged: (_) => onToggle(),
            activeThumbColor: AppColors.success,
          ),
        ],
      ),
    );
  }
}
