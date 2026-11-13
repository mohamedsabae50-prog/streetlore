import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:streetlore/data/cairo_seed.dart';
import 'package:streetlore/data/models/place_model.dart';
import 'package:streetlore/logic/governorate_provider.dart';
import 'package:streetlore/logic/place_provider.dart';

void main() {
  test('saved places and lookups include both governorates', () async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key',
    );
    final cairoPlace = cairoSeedPlaces.first;
    const alexandriaPlace = PlaceModel(
      id: 'alexandria-saved-place',
      nameEn: 'Alexandria saved place',
      descriptionEn: 'Alexandria landmark',
      imageUrl: '',
      rating: 4,
      lat: 31.2,
      lng: 29.9,
      governorate: 'alexandria',
    );
    final governorates = GovernorateProvider();
    final provider = PlaceProvider(
      watchRemoteUpdates: false,
      governorates: governorates,
      initialPlaces: [alexandriaPlace, ...cairoSeedPlaces],
    );
    addTearDown(provider.dispose);
    addTearDown(governorates.dispose);

    await provider.toggleSave(cairoPlace);
    await provider.toggleSave(alexandriaPlace);

    expect(provider.findById(cairoPlace.id), same(cairoPlace));
    expect(provider.findById(alexandriaPlace.id), same(alexandriaPlace));
    expect(provider.savedPlaces, hasLength(2));

    expect(governorates.unlockAndSelectGovernorate('cairo'), isTrue);
    expect(provider.savedPlaces, hasLength(2));
    expect(provider.findById(alexandriaPlace.id), same(alexandriaPlace));

    expect(governorates.unlockAndSelectGovernorate('alexandria'), isTrue);
    expect(provider.savedPlaces, hasLength(2));
    expect(provider.findById(cairoPlace.id), same(cairoPlace));
  });
}
