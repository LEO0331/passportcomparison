import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passportcomparison/main.dart' as app;
import 'package:patrol/patrol.dart';

void main() {
  patrolTest('compare two passports and reopen a saved preset', ($) async {
    app.main();
    await $.pumpAndSettle();

    expect(find.text('Passport A'), findsOneWidget);
    expect(find.text('Passport B'), findsOneWidget);
    expect(find.text('Passport C'), findsNothing);

    Future<void> selectPassport(
      String slot,
      String query,
      String country,
    ) async {
      await $(find.text('Passport $slot')).tap();
      final search = find.widgetWithText(TextField, 'Search passports');
      await $.tester.enterText(search, query);
      await $.pumpAndSettle();
      await $(find.text(country)).tap();
    }

    await selectPassport('A', 'Taiw', 'Taiwan');
    await selectPassport('B', 'Japa', 'Japan');
    await $(
      find.textContaining('Shared visa-free access', findRichText: true),
    ).scrollTo();
    await $(find.text('Save preset')).tap();
    await $.tester.enterText(
      find.byType(TextField).last,
      'E2E Taiwan and Japan',
    );
    await $(find.text('Save')).tap();

    await $(find.byTooltip('Saved presets')).tap();
    await $(find.text('E2E Taiwan and Japan')).tap();
    await $('Passport A: Taiwan').waitUntilVisible();
    await $('Passport B: Japan').waitUntilVisible();
  });
}
