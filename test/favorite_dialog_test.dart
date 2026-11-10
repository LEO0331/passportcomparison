import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passportcomparison/main.dart';
import 'package:passportcomparison/models/entry_requirements.dart';
import 'package:shared_preferences/shared_preferences.dart';

final fixture = PassportDataset(
  metadata: DatasetMetadata(
    version: '1.3.0',
    commit: 'a' * 40,
    importedAt: '2026-11-10T00:00:00Z',
    newestVerified: '2026-10-22',
    passportCount: 3,
    destinationCount: 1,
    recordCount: 0,
    missingCount: 3,
    attribution: 'TravelRequirements.info — AXG Sp. z o.o. (CC BY 4.0)',
    license: 'CC-BY-4.0',
    sourceUrl: Uri.parse('https://travelrequirements.info/data/'),
  ),
  passports: const {
    'TW': Passport(code: 'TW', name: 'Taiwan'),
    'JP': Passport(code: 'JP', name: 'Japan'),
    'BE': Passport(code: 'BE', name: 'Belgium'),
  },
  destinations: const {
    'BR': Destination(code: 'BR', name: 'Brazil', region: 'Americas'),
  },
  entriesByDestination: const {},
);

Future<void> openPage(WidgetTester tester, {String? query}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: PassportComparePage(
        initialUri: Uri.parse(
          'https://example.test/passportcomparison/${query ?? ''}',
        ),
        loadDataset: () async => fixture,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> selectPassport(
  WidgetTester tester,
  String slot,
  String query,
  String name,
) async {
  await tester.tap(find.text('Passport $slot'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).first, query);
  await tester.pumpAndSettle();
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('starts with two selectors and saves a named preset', (
    tester,
  ) async {
    await openPage(tester);
    expect(find.text('Start'), findsNothing);
    expect(find.text('Passport A'), findsOneWidget);
    expect(find.text('Passport B'), findsOneWidget);
    expect(find.text('Passport C'), findsNothing);
    expect(find.text('About the data'), findsOneWidget);
    await tester.tap(find.text('Add passport'));
    await tester.pumpAndSettle();
    expect(find.text('Passport C'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove passport C'));
    await tester.pumpAndSettle();

    await selectPassport(tester, 'A', 'tai', 'Taiwan');
    await selectPassport(tester, 'B', 'jap', 'Japan');
    expect(find.text('Copy comparison link'), findsOneWidget);
    await tester.tap(find.text('Save preset'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'My Trip');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final stored = jsonDecode(prefs.getString('favorites_list')!) as List;
    expect(stored.single['title'], 'My Trip');
    expect(stored.single['codes'].take(2), ['TW', 'JP']);

    await tester.tap(find.byTooltip('Saved presets'));
    await tester.pumpAndSettle();
    expect(find.text('My Trip'), findsOneWidget);
  });

  testWidgets('restores valid links and rejects unsupported selections', (
    tester,
  ) async {
    await openPage(tester, query: '?passports=TW%2CJP');
    expect(find.text('Passport A: Taiwan'), findsOneWidget);
    expect(find.text('Passport B: Japan'), findsOneWidget);
    expect(find.text('Save preset'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await openPage(tester, query: '?passports=TW,ZZ');
    expect(find.textContaining('unsupported passport'), findsOneWidget);
    expect(find.text('Passport A'), findsOneWidget);
    expect(find.text('Save preset'), findsNothing);
  });

  testWidgets('restores a legacy preset with supported codes', (tester) async {
    SharedPreferences.setMockInitialValues({
      'favorites_list': jsonEncode([
        {
          'title': 'Legacy Trip',
          'date': '2024-01-01',
          'codes': ['TW', 'JP', 'ZZ', null, null],
          'years': ['2014', '2015', '2015'],
          'count': 3,
        },
      ]),
    });
    await openPage(tester);
    await tester.tap(find.byTooltip('Saved presets'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Legacy Trip'));
    await tester.pumpAndSettle();
    expect(find.text('Passport A: Taiwan'), findsOneWidget);
    expect(find.text('Passport B: Japan'), findsOneWidget);
    expect(find.text('Passport C'), findsOneWidget);
    expect(find.textContaining('unavailable or duplicated'), findsOneWidget);
  });
}
