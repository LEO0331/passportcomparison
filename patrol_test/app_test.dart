import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:passportcomparison/main.dart' as app;

void main() {
  patrolTest('chrome e2e user flow', ($) async {
    app.main();
    await $.pumpAndSettle();

    // Flutter web may expose only the accessibility gate initially.
    try {
      await $('Enable accessibility').tap();
    } catch (_) {}

    // Some builds show a one-time dismiss button after opening semantics.
    try {
      await $('Dismiss').tap();
    } catch (_) {}

    await $('2').tap();
    await $('Start').tap();

    await $(find.bySemanticsLabel('Passport 1')).tap();
    await $(find.bySemanticsLabel('Afghanistan')).tap();

    await $(find.bySemanticsLabel('Passport 2')).tap();
    await $(find.bySemanticsLabel('Albania')).tap();

    await $('Compare').tap();
    await $('Details').waitUntilVisible();

    await $('Details').tap();
    await $('Detailed Access Comparison').scrollTo();
    await $('Detailed Access Comparison').waitUntilVisible();

    await $('How many passports to compare today? (Max 5)').scrollTo();
    await $.tester.tap(
      find.bySemanticsLabel('Add to Favorite', skipOffstage: false).first,
      warnIfMissed: false,
    );
    await $.pumpAndSettle();
    await $.tester.tap(
      find.bySemanticsLabel('Save', skipOffstage: false).first,
      warnIfMissed: false,
    );
    await $.pumpAndSettle();

    await $.tester.tap(
      find.bySemanticsLabel('Open navigation menu', skipOffstage: false).first,
      warnIfMissed: false,
    );
    await $.pumpAndSettle();
    await $.tester.tap(
      find.bySemanticsLabel('Favorites', skipOffstage: false).first,
      warnIfMissed: false,
    );
    await $.pumpAndSettle();

    await $('Afghanistan vs Albania').waitUntilVisible();
  });
}
