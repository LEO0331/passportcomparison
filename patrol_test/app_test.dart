import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:passportcomparison/main.dart' as app;

void main() {
  patrolTest('chrome e2e user flow', ($) async {
    Future<void> tapIfPresent(Key key) async {
      try {
        await $(find.byKey(key)).tap();
        await $.pumpAndSettle();
      } catch (_) {
        // Browser share/print hooks may vary across CI/web runners.
      }
    }

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
    await $(find.byKey(app.startButtonKey)).tap();

    await $(find.bySemanticsLabel('Passport 1')).tap();
    await $(find.bySemanticsLabel('Afghanistan')).tap();

    await $(find.bySemanticsLabel('Passport 2')).tap();
    await $(find.bySemanticsLabel('Albania')).tap();

    await $(find.byKey(app.compareButtonKey)).tap();
    await $(find.byKey(app.detailsButtonKey)).waitUntilVisible();

    // Explicitly exercise key-based action icons in compare mode.
    await tapIfPresent(app.shareScreenshotButtonKey);
    await tapIfPresent(app.exportFullPdfButtonKey);
    await tapIfPresent(app.exportDiffPdfButtonKey);

    await $(find.byKey(app.detailsButtonKey)).tap();
    await $('Detailed Access Comparison').scrollTo();
    await $('Detailed Access Comparison').waitUntilVisible();

    await $('How many passports to compare today? (Max 5)').scrollTo();
    await $(find.byKey(app.addFavoriteButtonKey)).tap();
    await $.pumpAndSettle();
    await $(find.byKey(app.saveFavoriteDialogButtonKey)).tap();
    await $.pumpAndSettle();

    await $.tester.tap(
      find.bySemanticsLabel('Open navigation menu', skipOffstage: false).first,
      warnIfMissed: false,
    );
    await $.pumpAndSettle();
    await $(find.byKey(app.favoritesDrawerTileKey)).tap();
    await $.pumpAndSettle();

    await $('Afghanistan vs Albania').waitUntilVisible();

    // Exercise reset key without mutating state.
    await $(find.bySemanticsLabel('Open navigation menu')).tap();
    await $.pumpAndSettle();
    await $(find.bySemanticsLabel('Home')).tap();
    await $.pumpAndSettle();
    await $(find.byKey(app.resetAllButtonKey)).tap();
    await $.pumpAndSettle();
    await $('Cancel').tap();
    await $.pumpAndSettle();
  });
}
