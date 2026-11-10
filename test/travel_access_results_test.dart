import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passportcomparison/models/entry_requirements.dart';
import 'package:passportcomparison/models/travel_access_comparison.dart';
import 'package:passportcomparison/widgets/travel_access_results.dart';

void main() {
  final metadata = DatasetMetadata(
    version: 'fixture',
    commit: 'fixture-commit',
    importedAt: '2026-10-02T12:00:00Z',
    oldestVerified: '2026-10-01',
    newestVerified: '2026-10-01',
    passportCount: 2,
    destinationCount: 2,
    recordCount: 4,
    missingCount: 0,
    attribution: 'Fixture dataset attribution',
    license: 'CC-BY-4.0',
    sourceUrl: Uri.https('travelrequirements.info', '/data/'),
  );
  EntryRequirement entry(
    String passport,
    String destination,
    RequirementType type,
  ) => EntryRequirement(
    passportCode: passport,
    destinationCode: destination,
    type: type,
    datasetVersion: metadata.version,
    conditions: type == RequirementType.eta ? 'Apply before departure.' : null,
    sourceLevel: type == RequirementType.eta ? SourceLevel.policy : null,
    source: type == RequirementType.eta
        ? SourceMetadata(
            url: Uri.https('example.gov', '/travel'),
            name: 'Government entry guidance',
            verifiedAt: '2026-10-01',
            provenance: 'first-party',
          )
        : null,
  );

  final comparison = TravelAccessComparison.calculate(
    PassportDataset(
      metadata: metadata,
      passports: const {
        'TW': Passport(code: 'TW', name: 'Taiwan'),
        'JP': Passport(code: 'JP', name: 'Japan'),
      },
      destinations: const {
        'FR': Destination(code: 'FR', name: 'France', region: 'Europe'),
        'SG': Destination(code: 'SG', name: 'Singapore', region: 'Asia'),
      },
      entriesByDestination: {
        'FR': {
          'TW': entry('TW', 'FR', RequirementType.eta),
          'JP': entry('JP', 'FR', RequirementType.visaFree),
        },
        'SG': {
          'TW': entry('TW', 'SG', RequirementType.evisa),
          'JP': entry('JP', 'SG', RequirementType.evisa),
        },
      },
    ),
    ['TW', 'JP'],
  );

  Future<void> showComparison(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                AboutTravelData(metadata: metadata),
                TravelAccessResults(comparison: comparison),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('Shows categories, filters and citation details', (tester) async {
    await showComparison(tester, const Size(900, 1100));
    expect(find.byType(Table), findsOneWidget);
    expect(find.text('Shared visa-free access'), findsOneWidget);
    expect(find.text('Electronic travel authorization'), findsOneWidget);
    expect(find.text('Electronic visa'), findsNWidgets(2));

    await tester.tap(find.text('All destinations'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Differences only').last);
    await tester.pumpAndSettle();
    expect(find.text('Singapore'), findsNothing);

    await tester.tap(find.text('France'));
    await tester.pumpAndSettle();
    expect(find.text('Apply before departure.'), findsOneWidget);
    expect(find.text('General destination policy'), findsOneWidget);
    expect(find.text('Government entry guidance'), findsOneWidget);
    expect(find.text('Source verified on 2026-10-01'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('About the data'));
    await tester.pumpAndSettle();
    expect(
      find.text('Bundled snapshot imported on 2026-10-02'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Source verification dates range from 2026-10-01 to 2026-10-01',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Mobile cards support destination search', (tester) async {
    await showComparison(tester, const Size(360, 800));
    expect(find.byType(Table), findsNothing);
    expect(find.text('France'), findsOneWidget);
    final search = find.byType(TextField);
    await tester.ensureVisible(search);
    await tester.enterText(search, 'sing');
    await tester.pumpAndSettle();
    expect(find.text('France'), findsNothing);
    expect(find.text('Singapore'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
