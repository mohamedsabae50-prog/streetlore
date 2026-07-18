import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class PublicTransportScreen extends StatelessWidget {
  const PublicTransportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Public Transport'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        physics: const BouncingScrollPhysics(),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF14B8A6), Color(0xFF06B6D4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.directions_transit_rounded, color: Colors.white, size: 32),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Get around Alexandria with trams, buses, and taxis',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Tram Lines', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 8),
          ..._tramLines.map((t) => _TransportCard(
            icon: Icons.tram_rounded,
            color: const Color(0xFFEF4444),
            title: t['title'] as String,
            description: t['description'] as String,
            price: t['price'] as String,
            stations: (t['stations'] as List).cast<String>(),
          )),
          const SizedBox(height: 20),
          Text('Bus Routes', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 8),
          ..._busRoutes.map((b) => _TransportCard(
            icon: Icons.directions_bus_rounded,
            color: const Color(0xFFF59E0B),
            title: b['title'] as String,
            description: b['description'] as String,
            price: b['price'] as String,
            stations: (b['stations'] as List).cast<String>(),
          )),
          const SizedBox(height: 20),
          Text('Taxis & Microbuses', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 8),
          _TransportCard(
            icon: Icons.local_taxi_rounded,
            color: const Color(0xFFFBBF24),
            title: 'Cairo Taxi (Yellow)',
            description: 'Most common, metered. Working meter required by law.',
            price: 'Meter: EGP 5-7 base + EGP 2.5/km',
            stations: const ['Available citywide', 'Book via app or hail on street'],
          ),
          const SizedBox(height: 8),
          _TransportCard(
            icon: Icons.directions_car_rounded,
            color: const Color(0xFF8B5CF6),
            title: 'Uber / Careem',
            description: 'App-based. Cash or card. Surge pricing at peak hours.',
            price: 'EGP 30-100+ depending on distance',
            stations: const ['Download app', 'Set pickup & drop-off'],
          ),
          const SizedBox(height: 8),
          _TransportCard(
            icon: Icons.airport_shuttle_rounded,
            color: const Color(0xFF3B82F6),
            title: 'Microbus (Servis)',
            description: 'Shared 14-seater vans. Fixed routes, cheap.',
            price: 'EGP 3-10',
            stations: const ['Set routes', 'Wave to board'],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.tips_and_updates_rounded, color: AppColors.success, size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pro tip: Buy a single-ride tram ticket from the booth at the stop, or use the transport card (kahraba) for 10% off.',
                    style: TextStyle(
                      color: AppColors.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const List<Map<String, Object>> _tramLines = [
    {
      'title': 'Ramleh Line (Red)',
      'description': 'Most useful for tourists. Runs along the corniche from Raml Station to San Stefano.',
      'price': 'EGP 5 single ride',
      'stations': <String>['Raml Station', 'Saad Zaghloul', 'Stanley', 'Gleem', 'Sidi Gaber', 'Sporting', 'San Stefano'],
    },
    {
      'title': 'Ramleh Line (Blue)',
      'description': 'Inner-city branch toward Moharam Bek and the souqs.',
      'price': 'EGP 5 single ride',
      'stations': <String>['Raml Station', 'Attarin', 'Moharam Bek', 'Manshiya'],
    },
    {
      'title': 'Western Line',
      'description': 'Heads west toward Agami. Long ride, good for beach hoppers.',
      'price': 'EGP 7-10 single ride',
      'stations': <String>['Raml Station', 'Sidi Gaber', 'Hannoville', 'Sidi Bishr', 'Mandara', 'Agami'],
    },
  ];

  static const List<Map<String, Object>> _busRoutes = [
    {
      'title': 'CTA Bus 215',
      'description': 'Corniche route. Frequent, scenic, cheap.',
      'price': 'EGP 5-8',
      'stations': <String>['Raml Station', 'Corniche', 'Qaitbay Citadel', 'Anfushi'],
    },
    {
      'title': 'CTA Bus 730',
      'description': 'To Bibliotheca Alexandrina & Shatby.',
      'price': 'EGP 5',
      'stations': <String>['Raml Station', 'Bibliotheca', 'Shatby', 'San Stefano'],
    },
    {
      'title': 'East Bus (Abu Qir)',
      'description': 'Long route to Abu Qir Fort and seafood restaurants.',
      'price': 'EGP 10-15',
      'stations': <String>['Raml Station', 'Montaza', 'Mandara', 'Abu Qir'],
    },
  ];
}

class _TransportCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final String price;
  final List<String> stations;

  const _TransportCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.price,
    required this.stations,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                const Icon(Icons.payments_rounded, size: 12, color: AppColors.success),
                const SizedBox(width: 4),
                Text(
                  price,
                  style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                description,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Stops:',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < stations.length; i++) ...[
                  if (i > 0)
                    const Icon(Icons.arrow_forward_rounded, size: 12, color: AppColors.textHint),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      stations[i],
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
