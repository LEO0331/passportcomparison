import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/entry_requirements.dart';

class DatasetRepository {
  DatasetRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const assetPath = 'assets/data/passport_requirements.json';

  final AssetBundle _bundle;

  Future<PassportDataset> load() async =>
      decode(await _bundle.loadString(assetPath));

  static PassportDataset decode(String data, {DateTime? asOf}) {
    final currentDay = (asOf ?? DateTime.now())
        .toUtc()
        .toIso8601String()
        .split('T')
        .first;
    final document = _object(jsonDecode(data), 'dataset');
    if (document['format'] != 1) {
      throw const FormatException('Unsupported dataset format');
    }
    final metadata = _decodeMetadata(document['metadata']);
    final passports = <String, Passport>{};
    for (final raw in _array(document['passports'], 'passports')) {
      final fields = _tuple(raw, 'passport', 2, 3);
      final code = _code(fields[0]);
      if (passports.containsKey(code)) {
        throw FormatException('Duplicate passport', code);
      }
      passports[code] = Passport(
        code: code,
        name: _text(fields[1], 'passport name'),
        arabicName: fields.length == 3 ? _optionalText(fields[2]) : null,
      );
    }
    final destinations = <String, Destination>{};
    for (final raw in _array(document['destinations'], 'destinations')) {
      final fields = _tuple(raw, 'destination', 3, 4);
      final code = _code(fields[0]);
      if (destinations.containsKey(code)) {
        throw FormatException('Duplicate destination', code);
      }
      destinations[code] = Destination(
        code: code,
        name: _text(fields[1], 'destination name'),
        region: _text(fields[2], 'region'),
        arabicName: fields.length == 4 ? _optionalText(fields[3]) : null,
      );
    }

    final statuses = [
      for (final code in _array(document['statuses'], 'statuses'))
        RequirementType.fromCode(_text(code, 'requirement status')),
    ];
    if (statuses.toSet().length != statuses.length) {
      throw const FormatException('Duplicate requirement status');
    }
    final sources = [
      for (final raw in _array(document['sources'], 'sources'))
        _decodeSource(raw),
    ];
    final texts = [
      for (final raw in _array(document['texts'], 'texts'))
        _text(raw, 'entry text'),
    ];
    final entries = <String, Map<String, EntryRequirement>>{};
    var recordCount = 0;
    for (final destination in _object(document['entries'], 'entries').entries) {
      if (!destinations.containsKey(destination.key)) {
        throw FormatException('Unknown destination', destination.key);
      }
      final requirements = <String, EntryRequirement>{};
      for (final passport in _object(
        destination.value,
        'requirements',
      ).entries) {
        if (!passports.containsKey(passport.key)) {
          throw FormatException('Unknown passport', passport.key);
        }
        final fields = _tuple(passport.value, 'entry', 7, 7);
        final conditional = fields[5];
        if (conditional is! bool) {
          throw const FormatException('Invalid conditional-entry flag');
        }
        final validUntil = _date(fields[6]);
        final isExpired =
            validUntil != null && validUntil.compareTo(currentDay) < 0;
        final type = _at(statuses, fields[0], 'status');
        final source = fields[3] == null
            ? null
            : _at(sources, fields[3], 'source');
        final sourceLevel = switch (fields[4]) {
          'row' => SourceLevel.row,
          'policy' => SourceLevel.policy,
          null => null,
          _ => throw const FormatException('Unknown source level'),
        };
        if (sourceLevel != null && source == null) {
          throw const FormatException('Source level requires a source');
        }
        requirements[passport.key] = EntryRequirement(
          passportCode: passport.key,
          destinationCode: destination.key,
          type: isExpired ? RequirementType.unconfirmed : type,
          datasetVersion: metadata.version,
          stay: _entryText(fields[1], texts),
          conditions: _entryText(fields[2], texts),
          source: source,
          sourceLevel: sourceLevel,
          isConditional: conditional,
          validUntil: validUntil,
          isExpired: isExpired,
        );
        recordCount++;
      }
      entries[destination.key] = requirements;
    }
    if (passports.isEmpty ||
        destinations.isEmpty ||
        passports.length != metadata.passportCount ||
        destinations.length != metadata.destinationCount ||
        recordCount != metadata.recordCount ||
        passports.length * destinations.length - recordCount !=
            metadata.missingCount) {
      throw const FormatException('Dataset coverage does not match metadata');
    }
    return PassportDataset(
      metadata: metadata,
      passports: passports,
      destinations: destinations,
      entriesByDestination: entries,
    );
  }
}

DatasetMetadata _decodeMetadata(Object? raw) {
  final fields = _object(raw, 'metadata');
  final version = _text(fields['version'], 'version');
  final commit = _text(fields['commit'], 'commit');
  final importedAt = _text(fields['importedAt'], 'import timestamp');
  final oldest = _date(fields['oldestVerified']);
  final newest = _date(fields['newestVerified']);
  final attribution = _text(fields['attribution'], 'attribution');
  final license = _text(fields['license'], 'license');
  if (!RegExp(r'^[a-f0-9]{40}$').hasMatch(commit) ||
      DateTime.tryParse(importedAt) == null ||
      (oldest != null && newest != null && oldest.compareTo(newest) > 0) ||
      license != 'CC-BY-4.0' ||
      !attribution.contains('TravelRequirements.info') ||
      !attribution.contains('AXG Sp. z o.o.') ||
      !attribution.contains('CC BY 4.0')) {
    throw const FormatException('Invalid dataset provenance');
  }
  return DatasetMetadata(
    version: version,
    commit: commit,
    importedAt: importedAt,
    oldestVerified: oldest,
    newestVerified: newest,
    passportCount: _count(fields['passportCount']),
    destinationCount: _count(fields['destinationCount']),
    recordCount: _count(fields['entryCount']),
    missingCount: _count(fields['missingCount']),
    attribution: attribution,
    license: license,
    sourceUrl: _url(fields['sourceUrl']),
  );
}

SourceMetadata _decodeSource(Object? raw) {
  final fields = _tuple(raw, 'source', 5, 5);
  return SourceMetadata(
    url: _url(fields[0]),
    name: _text(fields[1], 'source name'),
    type: _optionalText(fields[2]),
    verifiedAt: _date(fields[3]),
    provenance: _optionalText(fields[4]),
  );
}

Map<String, Object?> _object(Object? value, String label) {
  if (value is Map<String, Object?>) return value;
  throw FormatException('Expected object for $label');
}

List<Object?> _array(Object? value, String label) {
  if (value is List<Object?>) return value;
  throw FormatException('Expected array for $label');
}

List<Object?> _tuple(Object? value, String label, int min, int max) {
  final fields = _array(value, label);
  if (fields.length < min || fields.length > max) {
    throw FormatException('Unexpected fields for $label');
  }
  return fields;
}

T _at<T>(List<T> values, Object? index, String label) {
  if (index is int && index >= 0 && index < values.length) return values[index];
  throw FormatException('Invalid $label index', index);
}

String _text(Object? value, String label) {
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('Expected text for $label');
}

String? _optionalText(Object? value) =>
    value == null ? null : _text(value, 'field');

String? _entryText(Object? value, List<String> texts) =>
    value == null ? null : _at(texts, value, 'entry text');

String _code(Object? value) {
  final code = _text(value, 'country code');
  if (RegExp(r'^[A-Z]{2}$').hasMatch(code)) return code;
  throw FormatException('Invalid country code', code);
}

int _count(Object? value) {
  if (value is int && value >= 0) return value;
  throw const FormatException('Invalid coverage count');
}

String? _date(Object? value) {
  if (value == null) return null;
  final text = _text(value, 'verification date');
  final date = DateTime.tryParse('${text}T00:00:00Z');
  if (date == null || date.toIso8601String().split('T').first != text) {
    throw FormatException('Invalid verification date', text);
  }
  return text;
}

Uri _url(Object? value) {
  final url = Uri.tryParse(_text(value, 'source URL'));
  if (url == null ||
      (url.scheme != 'https' && url.scheme != 'http') ||
      url.host.isEmpty ||
      url.userInfo.isNotEmpty) {
    throw const FormatException('Invalid source URL');
  }
  return url;
}
