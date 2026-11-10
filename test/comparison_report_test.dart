import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:passportcomparison/models/entry_requirements.dart';
import 'package:passportcomparison/models/travel_access_comparison.dart';
import 'package:passportcomparison/services/comparison_report.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'full and differences-only reports preserve the right source links',
    () async {
      final comparison = _comparison();
      final full = latin1.decode(await buildComparisonPdf(comparison));
      final differences = latin1.decode(
        await buildComparisonPdf(comparison, differencesOnly: true),
      );

      for (final report in [full, differences]) {
        expect(report, startsWith('%PDF-'));
        expect(report, contains('https://example.com/different'));
        expect(report, contains('https://example.com/dataset'));
        expect(report, contains('/ToUnicode'));
      }
      expect(full, contains('https://example.com/same'));
      expect(differences, isNot(contains('https://example.com/same')));
    },
  );
}

TravelAccessComparison _comparison() {
  const passports = {
    'TW': Passport(code: 'TW', name: '臺灣'),
    'JP': Passport(code: 'JP', name: '日本'),
    'GB': Passport(code: 'GB', name: 'United Kingdom'),
    'US': Passport(code: 'US', name: 'United States'),
    'AU': Passport(code: 'AU', name: 'Australia'),
  };
  const destinations = {
    'FR': Destination(code: 'FR', name: 'France', region: 'Europe'),
    'CA': Destination(code: 'CA', name: 'Canada', region: 'North America'),
  };
  final metadata = DatasetMetadata(
    version: '1.3.0',
    commit: '0000000000000000000000000000000000000000',
    importedAt: '2026-10-23T00:00:00Z',
    oldestVerified: '2026-10-21',
    newestVerified: '2026-10-22',
    passportCount: passports.length,
    destinationCount: destinations.length,
    recordCount: 9,
    missingCount: 1,
    attribution: 'Fixture publisher (CC BY 4.0)',
    license: 'CC-BY-4.0',
    sourceUrl: Uri.parse('https://example.com/dataset'),
  );
  const franceTypes = {
    'TW': RequirementType.eta,
    'JP': RequirementType.evisa,
    'GB': RequirementType.freedomOfMovement,
    'US': RequirementType.banned,
  };
  final dataset = PassportDataset(
    metadata: metadata,
    passports: passports,
    destinations: destinations,
    entriesByDestination: {
      'FR': {
        for (final entry in franceTypes.entries)
          entry.key: EntryRequirement(
            passportCode: entry.key,
            destinationCode: 'FR',
            type: entry.value,
            datasetVersion: metadata.version,
            sourceLevel: SourceLevel.row,
            source: SourceMetadata(
              name: 'Fixture passport-specific source',
              url: Uri.parse('https://example.com/different'),
              verifiedAt: '2026-10-22',
            ),
          ),
      },
      'CA': {
        for (final code in passports.keys)
          code: EntryRequirement(
            passportCode: code,
            destinationCode: 'CA',
            type: RequirementType.visaFree,
            datasetVersion: metadata.version,
            stay: '90 days',
            sourceLevel: SourceLevel.policy,
            source: SourceMetadata(
              name: 'Fixture policy source',
              url: Uri.parse('https://example.com/same'),
              verifiedAt: '2026-10-21',
            ),
          ),
      },
    },
  );
  return TravelAccessComparison.calculate(dataset, passports.keys.toList());
}
