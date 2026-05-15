import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'package:passportcomparison/main.dart';
import 'package:passportcomparison/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service_test.mocks.dart';

void main() {
  late MockClient mockClient;
  late ApiService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockClient = MockClient();
    service = ApiService(
      client: mockClient,
      localCountriesLoader: () async => '{"countries":[]}',
    );
  });

  testWidgets('saving a favorite uses the custom title in page flow', (
    WidgetTester tester,
  ) async {
    final countriesResponse = jsonEncode({
      'countries': [
        {
          'code': 'TW',
          'country': 'Taiwan',
          'region': 'Asia',
          'openness': 88.0,
          'has_data': true,
          'data': {
            '2024': {'rank': 10, 'visa_free_count': 150, 'total': 198},
          },
        },
        {
          'code': 'JP',
          'country': 'Japan',
          'region': 'Asia',
          'openness': 92.0,
          'has_data': true,
          'data': {
            '2024': {'rank': 2, 'visa_free_count': 190, 'total': 198},
          },
        },
      ],
    });

    when(
      mockClient.get(Uri.parse('${ApiService.baseUrl}/countries')),
    ).thenAnswer((_) async => http.Response(countriesResponse, 200));

    await tester.pumpWidget(
      MaterialApp(home: PassportComparePage(apiService: service)),
    );

    await tester.tap(find.byKey(startButtonKey));
    await tester.pumpAndSettle();

    final countryDropdowns = find.byType(DropdownButton<String>);

    await tester.ensureVisible(countryDropdowns.first);
    await tester.tap(countryDropdowns.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Taiwan').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(countryDropdowns.at(2));
    await tester.tap(countryDropdowns.at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Japan').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(compareButtonKey));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(addFavoriteButtonKey));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'My Trip');
    await tester.tap(find.byKey(saveFavoriteDialogButtonKey));
    await tester.pumpAndSettle();

    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(favoritesDrawerTileKey));
    await tester.pumpAndSettle();

    expect(find.text('My Trip'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    final storedFavorites =
        json.decode(prefs.getString('favorites_list') ?? '[]') as List<dynamic>;

    expect(storedFavorites, hasLength(1));
    expect(storedFavorites.first['title'], 'My Trip');
  });
}
