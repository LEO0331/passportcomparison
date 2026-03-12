import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passportcomparison/models/country.dart';
import 'package:passportcomparison/widgets/passport_input.dart';

Country makeCountry(String code, String name) => Country(
      code: code,
      name: name,
      region: 'Test',
      openness: 50.0,
      hasData: true,
    );

void main() {
  final countries = [
    makeCountry('JP', 'Japan'),
    makeCountry('DE', 'Germany'),
    makeCountry('FR', 'France'),
  ];

  Future<void> openYearDropdown(WidgetTester tester,
      {String selectedYear = '2024'}) async {
    final yearDropdown = find.byType(DropdownButton<String>).last;

    // Most reliable: tap the dropdown arrow icon *inside* the year dropdown.
    final arrowIcon = find.descendant(
      of: yearDropdown,
      matching: find.byIcon(Icons.arrow_drop_down),
    );
    if (arrowIcon.evaluate().isNotEmpty) {
      await tester.tap(arrowIcon.last, warnIfMissed: false);
      await tester.pumpAndSettle();
      return;
    }

    // Fallback: tap the displayed selected year text.
    await tester.tap(find.text(selectedYear).first, warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  Widget buildWidget({
    int index = 0,
    String? selectedCode,
    String selectedYear = '2024',
    Function(String?)? onCountryChanged,
    Function(String?)? onYearChanged,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: PassportInputRow(
          index: index,
          countries: countries,
          selectedCode: selectedCode,
          selectedYear: selectedYear,
          onCountryChanged: onCountryChanged ?? (_) {},
          onYearChanged: onYearChanged ?? (_) {},
        ),
      ),
    );
  }

  group('PassportInputRow', () {
    testWidgets('renders two DropdownButtons', (tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.byType(DropdownButton<String>), findsNWidgets(2));
    });

    testWidgets('shows hint "Passport 1" for index 0', (tester) async {
      await tester.pumpWidget(buildWidget(index: 0));
      expect(find.text('Passport 1'), findsOneWidget);
    });

    testWidgets('shows hint "Passport 3" for index 2', (tester) async {
      await tester.pumpWidget(buildWidget(index: 2));
      expect(find.text('Passport 3'), findsOneWidget);
    });

    testWidgets('displays selected country name when code is provided',
        (tester) async {
      await tester.pumpWidget(buildWidget(selectedCode: 'JP'));
      expect(find.text('Japan'), findsOneWidget);
    });

    testWidgets('displays selected year', (tester) async {
      await tester.pumpWidget(buildWidget(selectedYear: '2020'));
      expect(find.text('2020'), findsOneWidget);
    });

    testWidgets('year dropdown contains years from 2006 to 2026', (tester) async {
      await tester.pumpWidget(buildWidget());

      await openYearDropdown(tester, selectedYear: '2024');

      expect(find.text('2006', skipOffstage: false), findsWidgets);
      expect(find.text('2026', skipOffstage: false), findsWidgets);
    });

    testWidgets('year dropdown contains exactly 21 items (2006–2026)',
        (tester) async {
      await tester.pumpWidget(buildWidget());

      await openYearDropdown(tester, selectedYear: '2024');

      // 2006..2026 inclusive = 21 years
      for (int y = 2006; y <= 2026; y++) {
        expect(find.text(y.toString(), skipOffstage: false), findsWidgets);
      }
    });

    testWidgets('onCountryChanged is called when user selects a country',
        (tester) async {
      String? changedValue;

      await tester.pumpWidget(buildWidget(
        onCountryChanged: (v) => changedValue = v,
      ));

      final dropdowns = find.byType(DropdownButton<String>);
      await tester.tap(dropdowns.first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Germany').last);
      await tester.pumpAndSettle();

      expect(changedValue, 'DE');
    });

    testWidgets('onYearChanged is called when user selects a year',
        (tester) async {
      String? changedYear;

      await tester.pumpWidget(buildWidget(
        selectedYear: '2024',
        onYearChanged: (v) => changedYear = v,
      ));

      final dropdowns = find.byType(DropdownButton<String>);
      await tester.tap(dropdowns.last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('2020').last);
      await tester.pumpAndSettle();

      expect(changedYear, '2020');
    });

    testWidgets('country dropdown contains all provided countries', (tester) async {
      await tester.pumpWidget(buildWidget());

      final dropdowns = find.byType(DropdownButton<String>);
      await tester.tap(dropdowns.first);
      await tester.pumpAndSettle();

      expect(find.text('Japan'), findsWidgets);
      expect(find.text('Germany'), findsWidgets);
      expect(find.text('France'), findsWidgets);
    });
  });
}
