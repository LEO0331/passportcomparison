import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passportcomparison/models/entry_requirements.dart';
import 'package:passportcomparison/models/travel_access_comparison.dart';
import 'package:passportcomparison/services/dataset_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'loads the shipped snapshot for a Taiwan and Japan comparison',
    () async {
      final dataset = await DatasetRepository().load();
      final comparison = TravelAccessComparison.calculate(dataset, [
        'TW',
        'JP',
      ]);

      expect(comparison.passports.map((passport) => passport.code), [
        'TW',
        'JP',
      ]);
      expect(dataset.metadata.recordCount, greaterThan(0));
      expect(comparison.rows.length, dataset.metadata.destinationCount - 2);
      expect(
        comparison.rows
            .expand((row) => row.requirements)
            .where((entry) => entry.sourceLevel == SourceLevel.row),
        isNotEmpty,
      );
      expect(
        comparison.rows
            .expand((row) => row.requirements)
            .where((entry) => entry.sourceLevel == SourceLevel.policy),
        isNotEmpty,
      );
      expect(comparison.combinedVisaFree, greaterThan(0));
    },
  );

  test('parses every canonical status without merging categories', () {
    const expected = {
      'visa-free': RequirementType.visaFree,
      'visa-on-arrival': RequirementType.visaOnArrival,
      'eta': RequirementType.eta,
      'evisa': RequirementType.evisa,
      'embassy-visa': RequirementType.embassyVisa,
      'visa-required': RequirementType.visaRequired,
      'freedom-of-movement': RequirementType.freedomOfMovement,
      'travel-permit': RequirementType.travelPermit,
      'banned': RequirementType.banned,
      'unconfirmed': RequirementType.unconfirmed,
    };
    expect({
      for (final type in RequirementType.values) type.code: type,
    }, expected);
    for (final entry in expected.entries) {
      expect(RequirementType.fromCode(entry.key), entry.value);
    }
    expect(
      () => RequirementType.fromCode('unsupported'),
      throwsFormatException,
    );
  });

  test(
    'loads bundled data and preserves provenance and missing records',
    () async {
      final bundle = _FixtureBundle(jsonEncode(_document()));
      final dataset = await DatasetRepository(bundle: bundle).load();
      expect(bundle.requests, [DatasetRepository.assetPath]);
      expect(dataset.metadata.version, '1.3.0');
      expect(dataset.metadata.recordCount, 21);
      final row = dataset.requirement('TW', 'ES');
      expect(row.type, RequirementType.visaFree);
      expect(row.stay, '90 days within 180 days');
      expect(row.sourceLevel, SourceLevel.row);
      expect(row.verified, '2026-10-01');
      expect(row.source?.url, Uri.parse('https://example.gov/rules'));
      expect(row.source?.name, 'Border authority');
      expect(row.source?.type, 'government');
      expect(row.source?.provenance, 'first-party');
      expect(row.datasetVersion, '1.3.0');
      final missing = dataset.requirement('JP', 'IE');
      expect(missing.passportCode, 'JP');
      expect(missing.destinationCode, 'IE');
      expect(missing.type, RequirementType.unconfirmed);
      expect(missing.source, isNull);
      expect(dataset.requirement('US', 'IE').type, RequirementType.unconfirmed);
      expect(dataset.passports['JP']?.nameFor('ar-AE'), 'اليابان');
    },
  );

  test('rejects invalid snapshot schema, duplicate codes, and count drift', () {
    final badVersion = _document()..['format'] = 2;
    final duplicate = _document();
    final passports = duplicate['passports']! as List;
    passports[1] = passports.first;
    final badCoverage = _document();
    (badCoverage['metadata']! as Map)['entryCount'] = 0;
    final invalidDate = _document();
    (invalidDate['metadata']! as Map)['newestVerified'] = '2026-02-30';
    final invalidUrl = _document();
    (invalidUrl['sources']! as List).first[0] = 'javascript:invalid';
    for (final document in [
      badVersion,
      duplicate,
      badCoverage,
      invalidDate,
      invalidUrl,
    ]) {
      expect(
        () => DatasetRepository.decode(jsonEncode(document)),
        throwsFormatException,
      );
    }
  });

  test('handles unavailable bundled data as a load error', () async {
    await expectLater(
      DatasetRepository(bundle: _FixtureBundle(null)).load(),
      throwsStateError,
    );
  });

  test('keeps dated requirements through the named UTC day', () {
    final document = _document();
    final entries = document['entries']! as Map;
    entries['ES']['TW'] = [0, null, null, 0, 'row', false, '2026-11-10'];
    final json = jsonEncode(document);
    final endOfDay = DatasetRepository.decode(
      json,
      asOf: DateTime.utc(2026, 11, 10, 23, 59),
    ).requirement('TW', 'ES');
    expect(endOfDay.confirmedVisaFree, isTrue);
    expect(endOfDay.validUntil, '2026-11-10');
    final after = DatasetRepository.decode(
      json,
      asOf: DateTime.utc(2026, 11, 11),
    ).requirement('TW', 'ES');
    expect(after.isUnknown, isTrue);
    expect(after.isExpired, isTrue);
    expect(after.verified, '2026-10-01');
  });

  test('resolves indexed text and rejects invalid text references', () {
    final document = _document();
    final entries = document['entries']! as Map;
    final dataset = DatasetRepository.decode(jsonEncode(document));
    expect(dataset.requirement('TW', 'ES').stay, '90 days within 180 days');
    expect(
      dataset.requirement('US', 'FR').conditions,
      'Biometric passports only.',
    );
    entries['ES']['TW'][1] = 3;
    expect(
      () => DatasetRepository.decode(jsonEncode(document)),
      throwsFormatException,
    );
  });

  test(
    'two passports count objective differences and exclude domestic rows',
    () {
      final comparison = _compare(['TW', 'JP']);
      expect(comparison.rows.map((row) => row.destination.code), [
        'CA',
        'FR',
        'IE',
        'SG',
        'ES',
      ]);
      expect(comparison.sharedVisaFree, 1);
      expect(comparison.combinedVisaFree, 3);
      expect(comparison.differentCategories, 2);
      expect(comparison.unknown, 1);
      expect(comparison.visaFreeOnlyByPassport, {'TW': 1, 'JP': 0});
      expect(comparison.visaFreeDifferences, 1);
      expect(
        comparison
            .filteredRows(filter: ComparisonFilter.visaFreeDifferences)
            .map((row) => row.destination.code),
        ['ES'],
      );
      expect(
        comparison
            .filteredRows(filter: ComparisonFilter.differences, region: 'Asia')
            .map((row) => row.destination.code),
        ['SG'],
      );
      expect(
        comparison.filteredRows(query: ' fr ').single.destination.code,
        'FR',
      );
      expect(
        comparison
            .filteredRows(query: 'إسبانيا', locale: 'ar')
            .single
            .destination
            .code,
        'ES',
      );
    },
  );

  test('supports three through five passports with conditional access', () {
    for (final count in [3, 4, 5]) {
      final comparison = _compare(
        ['TW', 'JP', 'US', 'GB', 'AU'].take(count).toList(),
      );
      expect(comparison.passports.length, count);
      expect(comparison.sharedVisaFree, 0);
      expect(comparison.combinedVisaFree, 3);
      expect(comparison.visaFreeOnlyByPassport['TW'], 1);
      expect(comparison.unknown, 2);
      final france = comparison.filteredRows(query: 'France').single;
      expect(france.requirements[2].type, RequirementType.visaFree);
      expect(france.requirements[2].isConditional, isTrue);
      expect(france.requirements[2].conditions, 'Biometric passports only.');
      expect(france.requirements[2].confirmedVisaFree, isFalse);
      expect(france.hasVisaFreeDifference, isFalse);
    }
  });

  test('rejects unsupported, duplicate, and out-of-range selections', () {
    for (final codes in [
      ['TW'],
      ['TW', 'TW'],
      ['TW', 'ZZ'],
      ['TW', 'JP', 'US', 'GB', 'AU', 'CA'],
    ]) {
      expect(() => _compare(codes), throwsArgumentError);
    }
  });
}

TravelAccessComparison _compare(List<String> codes) =>
    TravelAccessComparison.calculate(
      DatasetRepository.decode(jsonEncode(_document())),
      codes,
    );

Map<String, Object?> _document() => {
  'format': 1,
  'metadata': {
    'version': '1.3.0',
    'commit': '0123456789012345678901234567890123456789',
    'importedAt': '2026-11-10T10:00:00Z',
    'oldestVerified': '2026-10-01',
    'newestVerified': '2026-10-01',
    'attribution':
        'TravelRequirements.info — Entry Requirements Dataset, '
        'AXG Sp. z o.o., https://travelrequirements.info/data/ (CC BY 4.0)',
    'license': 'CC-BY-4.0',
    'sourceUrl': 'https://travelrequirements.info/data/',
    'passportCount': 5,
    'destinationCount': 7,
    'entryCount': 21,
    'missingCount': 14,
  },
  'passports': [
    ['TW', 'Taiwan'],
    ['JP', 'Japan', 'اليابان'],
    ['US', 'United States'],
    ['GB', 'United Kingdom'],
    ['AU', 'Australia'],
  ],
  'destinations': [
    ['JP', 'Japan', 'Asia'],
    ['TW', 'Taiwan', 'Asia'],
    ['FR', 'France', 'Europe'],
    ['SG', 'Singapore', 'Asia'],
    ['IE', 'Ireland', 'Europe'],
    ['CA', 'Canada', 'Americas'],
    ['ES', 'Spain', 'Europe', 'إسبانيا'],
  ],
  'statuses': ['visa-free', 'evisa', 'eta', 'visa-required', 'unconfirmed'],
  'texts': ['90 days within 180 days', 'Biometric passports only.'],
  'sources': [
    [
      'https://example.gov/rules',
      'Border authority',
      'government',
      '2026-10-01',
      'first-party',
    ],
  ],
  'entries': {
    'TW': {'JP': _entry(0)},
    'JP': {'TW': _entry(0)},
    'FR': {
      'TW': _entry(0),
      'JP': _entry(0),
      'US': [0, null, 1, 0, 'policy', true, null],
      'GB': _entry(0),
      'AU': _entry(0),
    },
    'SG': {
      'TW': _entry(1),
      'JP': _entry(2),
      'US': _entry(3),
      'GB': _entry(2),
      'AU': _entry(2),
    },
    'IE': {'TW': _entry(0), 'US': _entry(4)},
    'CA': {'TW': _entry(2), 'JP': _entry(2)},
    'ES': {
      'TW': [0, 0, null, 0, 'row', false, null],
      'JP': _entry(1),
      'US': _entry(1),
      'GB': _entry(1),
      'AU': _entry(1),
    },
  },
};

List<Object?> _entry(int status) => [
  status,
  null,
  null,
  null,
  null,
  false,
  null,
];

class _FixtureBundle extends CachingAssetBundle {
  _FixtureBundle(this.fixture);

  final String? fixture;
  final requests = <String>[];

  @override
  Future<ByteData> load(String key) async => throw UnimplementedError();

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    requests.add(key);
    return fixture ?? (throw StateError('Missing asset'));
  }
}
