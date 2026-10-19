import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streetlore/core/services/widget_sync_service.dart';
import 'package:streetlore/data/models/place_model.dart';
import 'package:streetlore/logic/locale_provider.dart';
import 'package:streetlore/logic/place_provider.dart';

class _FakePlaceProvider extends ChangeNotifier implements PlaceProvider {
  _FakePlaceProvider(this.places);

  @override
  final List<PlaceModel> places;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('writes the daily place and localized content for the widget', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    var widgetUpdated = false;
    const channel = MethodChannel('streetlore/widget');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'update');
          widgetUpdated = true;
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final places = [
      const PlaceModel(
        id: 'place-a',
        nameEn: 'Place A',
        nameAr: 'المكان أ',
        descriptionEn: 'English description A',
        descriptionAr: 'وصف المكان أ',
        imageUrl: '',
        rating: 4.5,
        lat: 31.2,
        lng: 29.9,
      ),
      const PlaceModel(
        id: 'place-b',
        nameEn: 'Place B',
        nameAr: 'المكان ب',
        descriptionEn: 'English description B',
        descriptionAr: 'وصف المكان ب',
        imageUrl: '',
        rating: 4.2,
        lat: 31.3,
        lng: 29.8,
      ),
    ];
    final localeProvider = LocaleProvider();
    await localeProvider.setLocale(const Locale('ar'));
    final placeProvider = _FakePlaceProvider(places);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PlaceProvider>.value(value: placeProvider),
          ChangeNotifierProvider<LocaleProvider>.value(value: localeProvider),
        ],
        child: const MaterialApp(
          home: Builder(key: ValueKey('widget-sync-context'), builder: _home),
        ),
      ),
    );

    final context = tester.element(
      find.byKey(const ValueKey('widget-sync-context')),
    );
    await WidgetSyncService.updateWidgetData(context);

    final preferences = await SharedPreferences.getInstance();
    final day =
        DateTime.now().toUtc().millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
    final place = places[day % places.length];
    expect(preferences.getString('streetlore_widget_v1.locale'), 'ar');
    expect(preferences.getString('streetlore_widget_v1.place_id'), place.id);
    expect(
      preferences.getString('streetlore_widget_v1.place_title_ar'),
      place.nameAr,
    );
    expect(
      preferences.getString('streetlore_widget_v1.place_snippet_ar'),
      place.descriptionAr,
    );
    expect(widgetUpdated, isTrue);
  });
}

Widget _home(BuildContext context) => const SizedBox.shrink();
