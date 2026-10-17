import 'package:flutter_test/flutter_test.dart';
import 'package:streetlore/data/models/itinerary_model.dart';

void main() {
  test(
    'reads localized tour fields and resolves them for the active locale',
    () {
      final tour = ItineraryModel.fromJson({
        'id': 'family-day',
        'title_en': 'Family Day',
        'title_ar': 'يوم عائلي',
        'description_en': 'An English description.',
        'description_ar': 'وصف عربي.',
        'duration_en': 'Full Day',
        'duration_ar': 'يوم كامل',
      });

      expect(tour.localizedTitle('en'), 'Family Day');
      expect(tour.localizedTitle('ar'), 'يوم عائلي');
      expect(tour.localizedDescription('en'), 'An English description.');
      expect(tour.localizedDescription('ar'), 'وصف عربي.');
      expect(tour.localizedDuration('en'), 'Full Day');
      expect(tour.localizedDuration('ar'), 'يوم كامل');

      final durationFallback = ItineraryModel.fromJson({
        'id': 'short-tour',
        'title': 'Short tour',
        'description': 'Description.',
        'duration': '4 Hours',
      });
      expect(durationFallback.localizedDuration('ar'), '4 ساعات');
    },
  );
}
