import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';

class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  Future<void> _call(BuildContext context, String number) async {
    HapticFeedback.lightImpact();
    final uri = Uri(scheme: 'tel', path: number);
    final ok = await canLaunchUrl(uri);
    if (!ok) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot place call to $number')),
      );
      return;
    }
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Emergency',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _HeaderCard(),
          const SizedBox(height: 22),
          _SectionHeader(
            icon: Icons.phone_in_talk_rounded,
            color: const Color(0xFFEF4444),
            title: 'Emergency Numbers',
          ),
          const SizedBox(height: 10),
          ..._emergencyNumbers.map((e) => _CallCard(
                title: e.title,
                number: e.number,
                color: e.color,
                icon: e.icon,
                onTap: () => _call(context, e.number),
              )),
          const SizedBox(height: 22),
          _SectionHeader(
            icon: Icons.local_hospital_rounded,
            color: const Color(0xFFEF4444),
            title: 'Hospitals',
          ),
          const SizedBox(height: 10),
          ..._hospitals.map((h) => _PlaceCard24(
                title: h.name,
                subtitle: h.address,
                phone: h.phone,
                color: h.color,
                onCall: () => _call(context, h.phone),
              )),
          const SizedBox(height: 22),
          _SectionHeader(
            icon: Icons.flag_rounded,
            color: const Color(0xFF6366F1),
            title: 'Embassies & Consulates',
          ),
          const SizedBox(height: 10),
          ..._embassies.map((e) => _PlaceCard24(
                title: e.name,
                subtitle: e.address,
                phone: e.phone,
                color: e.color,
                onCall: () => _call(context, e.phone),
              )),
          const SizedBox(height: 22),
          _SectionHeader(
            icon: Icons.local_pharmacy_rounded,
            color: const Color(0xFF10B981),
            title: '24h Pharmacies',
          ),
          const SizedBox(height: 10),
          ..._pharmacies.map((p) => _PlaceCard24(
                title: p.name,
                subtitle: p.address,
                phone: p.phone,
                color: p.color,
                onCall: () => _call(context, p.phone),
              )),
          const SizedBox(height: 22),
          _SectionHeader(
            icon: Icons.taxi_alert_rounded,
            color: const Color(0xFFF59E0B),
            title: 'Transport',
          ),
          const SizedBox(height: 10),
          ..._transport.map((t) => _CallCard(
                title: t.title,
                number: t.number,
                color: t.color,
                icon: t.icon,
                onTap: () => _call(context, t.number),
              )),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.health_and_safety_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Stay safe in Alexandria',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap any number to call. Save this page for quick access.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  const _SectionHeader({
    required this.icon,
    required this.color,
    required this.title,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _CallCard extends StatelessWidget {
  final String title;
  final String number;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  const _CallCard({
    required this.title,
    required this.number,
    required this.color,
    required this.icon,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        number,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.phone_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceCard24 extends StatelessWidget {
  final String title;
  final String subtitle;
  final String phone;
  final Color color;
  final VoidCallback onCall;
  const _PlaceCard24({
    required this.title,
    required this.subtitle,
    required this.phone,
    required this.color,
    required this.onCall,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 12, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined,
                          size: 12, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Text(
                        phone,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onCall,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.phone_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Emerg {
  final String title;
  final String number;
  final Color color;
  final IconData icon;
  const _Emerg(this.title, this.number, this.color, this.icon);
}

class _Contact {
  final String name;
  final String address;
  final String phone;
  final Color color;
  const _Contact(this.name, this.address, this.phone, this.color);
}

const _emergencyNumbers = <_Emerg>[
  _Emerg('Police', '122', Color(0xFF3B82F6), Icons.local_police_rounded),
  _Emerg('Ambulance', '123', Color(0xFFEF4444), Icons.medical_services_rounded),
  _Emerg('Fire', '180', Color(0xFFF59E0B), Icons.local_fire_department_rounded),
  _Emerg('Tourist Police', '126', Color(0xFF8B5CF6), Icons.tour_rounded),
  _Emerg('Coast Guard', '122', Color(0xFF0EA5E9), Icons.directions_boat_rounded),
];

const _transport = <_Emerg>[
  _Emerg('Careem (Ride)', '16622', Color(0xFF10B981), Icons.local_taxi_rounded),
  _Emerg('Uber Egypt', '16222', Color(0xFF0F172A), Icons.directions_car_rounded),
  _Emerg('Alexandria Taxi', '19595', Color(0xFFF59E0B), Icons.local_taxi_rounded),
];

const _hospitals = <_Contact>[
  _Contact(
    'Alexandria Main University Hospital',
    'Al Khartoum Sq, Khartoum St, Sidi Gaber',
    '03-4861566',
    Color(0xFFEF4444),
  ),
  _Contact(
    'Abo Qir General Hospital',
    'Abo Qir Main Rd, Abo Qir',
    '03-5600420',
    Color(0xFFEF4444),
  ),
  _Contact(
    'Gamal Abdel Nasser Hospital',
    'Corniche Rd, Gharb District',
    '03-4819000',
    Color(0xFFEF4444),
  ),
  _Contact(
    'Smouha International Hospital',
    'Smouha, 14th of May Bridge Rd',
    '03-4290099',
    Color(0xFFEF4444),
  ),
  _Contact(
    'Dar Ismail Eye Hospital',
    'Sidi Gaber, Alexandria',
    '03-5450000',
    Color(0xFFEF4444),
  ),
];

const _embassies = <_Contact>[
  _Contact(
    'USA Consulate',
    '3 Daoud St, Roushdy, Alexandria',
    '03-4861009',
    Color(0xFF3B82F6),
  ),
  _Contact(
    'UK Consulate',
    '3 Daoud St, Roushdy, Alexandria',
    '03-4861009',
    Color(0xFF3B82F6),
  ),
  _Contact(
    'German Consulate',
    '8 El Horreya Rd, Roushdy',
    '03-4869433',
    Color(0xFF3B82F6),
  ),
  _Contact(
    'French Consulate',
    '2 El Fawatem St, Roushdy',
    '03-4861433',
    Color(0xFF3B82F6),
  ),
  _Contact(
    'Italian Consulate',
    '2 El Fawatem St, Roushdy',
    '03-4861433',
    Color(0xFF3B82F6),
  ),
  _Contact(
    'Russian Consulate',
    'Saba Pasha, Alexandria',
    '03-5832734',
    Color(0xFF3B82F6),
  ),
];

const _pharmacies = <_Contact>[
  _Contact(
    'El Ezaby Pharmacy (24h)',
    'Saad Zaghloul Sq, Mansheya',
    '19600',
    Color(0xFF10B981),
  ),
  _Contact(
    'Seif Pharmacy (24h)',
    'Roushdy Main St, Roushdy',
    '16343',
    Color(0xFF10B981),
  ),
  _Contact(
    'Fahmy Pharmacy (24h)',
    'Sidi Gaber, Alexandria',
    '03-5435000',
    Color(0xFF10B981),
  ),
];
