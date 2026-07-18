

class GeofenceAlert {
  final String placeId;
  final String placeName;
  final double lat;
  final double lng;
  final int radiusMeters;
  final bool enabled;
  final DateTime? lastTriggeredAt;

  const GeofenceAlert({
    required this.placeId,
    required this.placeName,
    required this.lat,
    required this.lng,
    this.radiusMeters = 500,
    this.enabled = true,
    this.lastTriggeredAt,
  });

  GeofenceAlert copyWith({
    bool? enabled,
    int? radiusMeters,
    DateTime? lastTriggeredAt,
  }) =>
      GeofenceAlert(
        placeId: placeId,
        placeName: placeName,
        lat: lat,
        lng: lng,
        radiusMeters: radiusMeters ?? this.radiusMeters,
        enabled: enabled ?? this.enabled,
        lastTriggeredAt: lastTriggeredAt ?? this.lastTriggeredAt,
      );

  Map<String, dynamic> toJson() => {
        'place_id': placeId,
        'place_name': placeName,
        'lat': lat,
        'lng': lng,
        'radius_meters': radiusMeters,
        'enabled': enabled,
        'last_triggered_at': lastTriggeredAt?.toIso8601String(),
      };

  factory GeofenceAlert.fromJson(Map<String, dynamic> json) => GeofenceAlert(
        placeId: json['place_id'] as String,
        placeName: json['place_name'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        radiusMeters: (json['radius_meters'] as num?)?.toInt() ?? 500,
        enabled: json['enabled'] as bool? ?? true,
        lastTriggeredAt: json['last_triggered_at'] == null
            ? null
            : DateTime.parse(json['last_triggered_at'] as String),
      );
}
