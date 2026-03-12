import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passportcomparison/models/country.dart';
import 'package:passportcomparison/widgets/comparison_table.dart';

// Stub packages used by ComparisonTable that don't affect logic under test
// Make sure pubspec.yaml includes: country_flags, sticky_headers, screenshot

Country makeCountry({
  required String code,
  required String name,
  bool hasData = true,
  double openness = 50.0,
}) => Country(
      code: code,
      name: name,
      region: 'Test',
      openness: openness,
      hasData: hasData,
    );

void main() {
  final japan = makeCountry(code: 'JP', name: 'Japan');
  final germany = makeCountry(code: 'DE', name: 'Germany');
  final france = makeCountry(code: 'FR', name: 'France');
  final china = makeCountry(code: 'CN', name: 'China');

  final allCountries = [japan, germany, france, china];

  Widget buildTable({
    List<String> selectedCodes = const ['JP', 'DE'],
    Map<String, Set<String>> visaFreeMap = const {},
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ComparisonTable(
            selectedCodes: selectedCodes,
            allCountries: allCountries,
            visaFreeMap: visaFreeMap,
          ),
        ),
      ),
    );
  }

  group('ComparisonTable', () {
    testWidgets('renders search field', (tester) async {
      await tester.pumpWidget(buildTable());
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('renders Diff Only filter chip', (tester) async {
      await tester.pumpWidget(buildTable());
      expect(find.text('Diff Only'), findsOneWidget);
    });

    testWidgets('renders "Destination" header', (tester) async {
      await tester.pumpWidget(buildTable());
      expect(find.text('Destination'), findsOneWidget);
    });

    testWidgets('shows all country names as destination rows', (tester) async {
      await tester.pumpWidget(buildTable());
      await tester.pump();

      expect(find.text('Japan'), findsWidgets);
      expect(find.text('Germany'), findsWidgets);
      expect(find.text('France'), findsWidgets);
      expect(find.text('China'), findsWidgets);
    });

    testWidgets('search filters destinations', (tester) async {
      await tester.pumpWidget(buildTable());
      await tester.enterText(find.byType(TextField), 'France');
      await tester.pump();

      expect(find.text('France'), findsWidgets);
      expect(find.text('China'), findsNothing);
    });

    testWidgets('search is case-insensitive', (tester) async {
      await tester.pumpWidget(buildTable());
      await tester.enterText(find.byType(TextField), 'france');
      await tester.pump();

      expect(find.text('France'), findsWidgets);
    });

    testWidgets('shows check icon when destination is in visa-free set',
        (tester) async {
      await tester.pumpWidget(buildTable(
        selectedCodes: ['JP'],
        visaFreeMap: {
          'JP': {'FR'},
        },
      ));
      await tester.pump();

      expect(find.byIcon(Icons.check_circle), findsWidgets);
    });

    testWidgets('shows cancel icon when destination is not visa-free',
        (tester) async {
      await tester.pumpWidget(buildTable(
        selectedCodes: ['JP'],
        visaFreeMap: {'JP': <String>{}},
      ));
      await tester.pump();

      expect(find.byIcon(Icons.cancel_outlined), findsWidgets);
    });

    testWidgets('shows N/A for passport without data', (tester) async {
      final noDataCountry = makeCountry(
        code: 'XX',
        name: 'NoData',
        hasData: false,
      );
      final countries = [japan, france, noDataCountry];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ComparisonTable(
                selectedCodes: ['XX'],
                allCountries: countries,
                visaFreeMap: {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('N/A'), findsWidgets);
    });

    testWidgets('Diff Only chip toggles state on tap', (tester) async {
      await tester.pumpWidget(buildTable());
      final chip = find.byType(FilterChip);
      expect(tester.widget<FilterChip>(chip).selected, false);

      await tester.tap(chip);
      await tester.pump();

      expect(tester.widget<FilterChip>(chip).selected, true);
    });

    testWidgets(
      'Diff Only hides rows where all passports share same status',
      (tester) async {
        // JP and DE both have FR visa-free → France should NOT appear in diff-only
        // JP has CN, DE does not → China SHOULD appear in diff-only
        await tester.pumpWidget(buildTable(
          selectedCodes: ['JP', 'DE'],
          visaFreeMap: {
            'JP': {'FR', 'CN'},
            'DE': {'FR'}, // DE doesn't have CN
          },
        ));

        await tester.tap(find.text('Diff Only'));
        await tester.pump();

        // China differs (JP=free, DE=required) → should be visible
        expect(find.text('China'), findsOneWidget);
        // France is same for both → should be hidden
        expect(find.text('France'), findsNothing);
      },
    );
  });
}
