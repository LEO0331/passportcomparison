import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passportcomparison/models/country.dart';
import 'package:passportcomparison/widgets/passport_filter.dart';

Country makeCountry({
  required String code,
  required String name,
  required String region,
  double openness = 50.0,
}) => Country(
      code: code,
      name: name,
      region: region,
      openness: openness,
      hasData: true,
    );

void main() {
  final allCountries = [
    makeCountry(code: 'JP', name: 'Japan', region: 'Asia', openness: 92.5),
    makeCountry(code: 'CN', name: 'China', region: 'Asia', openness: 40.0),
    makeCountry(code: 'DE', name: 'Germany', region: 'Europe', openness: 88.0),
    makeCountry(code: 'FR', name: 'France', region: 'Europe', openness: 85.0),
  ];

  Widget buildWidget({
    String? selectedCode,
    String selectedYear = '2024',
    Function(String?)? onCountryChanged,
    Function(String?)? onYearChanged,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PassportFilter(
            allCountries: allCountries,
            selectedCode: selectedCode,
            selectedYear: selectedYear,
            onCountryChanged: onCountryChanged ?? (_) {},
            onYearChanged: onYearChanged ?? (_) {},
          ),
        ),
      ),
    );
  }

  group('PassportFilter', () {
    testWidgets('renders Region dropdown', (tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.text('Region'), findsOneWidget);
    });

    testWidgets('renders Year dropdown', (tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.text('Year'), findsOneWidget);
    });

    testWidgets('renders country search dropdown hint', (tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.text('Search and Select Country'), findsOneWidget);
    });

    testWidgets('does NOT show OpennessIndicator when no country selected',
        (tester) async {
      await tester.pumpWidget(buildWidget(selectedCode: null));
      // OpennessIndicator contains "Openness" label
      expect(find.text('Openness'), findsNothing);
    });

    testWidgets('shows OpennessIndicator when a country is selected',
        (tester) async {
      await tester.pumpWidget(buildWidget(selectedCode: 'JP'));
      expect(find.text('Openness'), findsOneWidget);
    });

    testWidgets('shows correct openness score for selected country',
        (tester) async {
      await tester.pumpWidget(buildWidget(selectedCode: 'JP'));
      // Japan openness = 92.5
      expect(find.text('92.5'), findsOneWidget);
    });

    testWidgets('Region dropdown includes "All" option', (tester) async {
      await tester.pumpWidget(buildWidget());

      // Open region dropdown
      await tester.tap(find.text('All').first);
      await tester.pumpAndSettle();

      expect(find.text('All'), findsWidgets);
    });

    testWidgets('Region dropdown includes all unique regions', (tester) async {
      await tester.pumpWidget(buildWidget());

      await tester.tap(find.text('All').first);
      await tester.pumpAndSettle();

      expect(find.text('Asia'), findsOneWidget);
      expect(find.text('Europe'), findsOneWidget);
    });

    testWidgets('selected year is displayed', (tester) async {
      await tester.pumpWidget(buildWidget(selectedYear: '2023'));
      expect(find.text('2023'), findsOneWidget);
    });

    testWidgets('Year dropdown contains expected years', (tester) async {
      await tester.pumpWidget(buildWidget());

      await tester.tap(find.text('2024'));
      await tester.pumpAndSettle();

      expect(find.text('2024'), findsWidgets);
      expect(find.text('2023'), findsOneWidget);
      expect(find.text('2022'), findsOneWidget);
    });

    testWidgets('onYearChanged callback fires on year selection', (tester) async {
      String? selectedYear;

      await tester.pumpWidget(buildWidget(
        selectedYear: '2024',
        onYearChanged: (v) => selectedYear = v,
      ));

      await tester.tap(find.text('2024'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('2022').last);
      await tester.pumpAndSettle();

      expect(selectedYear, '2022');
    });
  });
}
