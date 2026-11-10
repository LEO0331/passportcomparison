enum RequirementType {
  visaFree('visa-free', 'Visa-free'),
  visaOnArrival('visa-on-arrival', 'Visa on arrival'),
  eta('eta', 'Electronic travel authorization'),
  evisa('evisa', 'Electronic visa'),
  embassyVisa('embassy-visa', 'Embassy visa required'),
  visaRequired('visa-required', 'Visa required'),
  freedomOfMovement('freedom-of-movement', 'Freedom of movement'),
  travelPermit('travel-permit', 'Travel permit'),
  banned('banned', 'Entry restriction'),
  unconfirmed('unconfirmed', 'Not confirmed');

  const RequirementType(this.code, this.label);

  final String code;
  final String label;

  static final _byCode = {for (final type in values) type.code: type};

  static RequirementType fromCode(String code) =>
      _byCode[code] ??
      (throw FormatException('Unknown requirement type', code));

  bool get isUnknown => this == unconfirmed;

  bool get isAdvanceAuthorization => switch (this) {
    eta || evisa || embassyVisa || visaRequired => true,
    _ => false,
  };
}

class Passport {
  const Passport({required this.code, required this.name, this.arabicName});

  final String code;
  final String name;
  final String? arabicName;

  String nameFor(String locale) => _localizedName(locale, name, arabicName);
}

class Destination {
  const Destination({
    required this.code,
    required this.name,
    required this.region,
    this.arabicName,
  });

  final String code;
  final String name;
  final String region;
  final String? arabicName;

  String nameFor(String locale) => _localizedName(locale, name, arabicName);
}

String _localizedName(String locale, String name, String? arabicName) =>
    locale.toLowerCase().split(RegExp('[-_]')).first == 'ar'
    ? arabicName ?? name
    : name;

enum SourceLevel {
  row('Passport-specific source'),
  policy('General destination policy');

  const SourceLevel(this.label);

  final String label;
}

class SourceMetadata {
  const SourceMetadata({
    required this.url,
    required this.name,
    this.type,
    this.verifiedAt,
    this.provenance,
  });

  final Uri url;
  final String name;
  final String? type;
  final String? verifiedAt;
  final String? provenance;
}

class EntryRequirement {
  const EntryRequirement({
    required this.passportCode,
    required this.destinationCode,
    required this.type,
    required this.datasetVersion,
    this.stay,
    this.conditions,
    this.source,
    this.sourceLevel,
    this.isConditional = false,
    this.validUntil,
    this.isExpired = false,
  });

  final String passportCode;
  final String destinationCode;
  final RequirementType type;
  final String datasetVersion;
  final String? stay;
  final String? conditions;
  final SourceMetadata? source;
  final SourceLevel? sourceLevel;
  final bool isConditional;
  final String? validUntil;
  final bool isExpired;

  String? get verified => source?.verifiedAt;
  bool get isUnknown => type.isUnknown;
  bool get confirmedVisaFree =>
      type == RequirementType.visaFree && !isConditional;
}

class DatasetMetadata {
  const DatasetMetadata({
    required this.version,
    required this.commit,
    required this.importedAt,
    this.oldestVerified,
    this.newestVerified,
    required this.passportCount,
    required this.destinationCount,
    required this.recordCount,
    required this.missingCount,
    required this.attribution,
    required this.license,
    required this.sourceUrl,
  });

  final String version;
  final String commit;
  final String importedAt;
  final String? oldestVerified;
  final String? newestVerified;
  final int passportCount;
  final int destinationCount;
  final int recordCount;
  final int missingCount;
  final String attribution;
  final String license;
  final Uri sourceUrl;
}

class PassportDataset {
  PassportDataset({
    required this.metadata,
    required Map<String, Passport> passports,
    required Map<String, Destination> destinations,
    required Map<String, Map<String, EntryRequirement>> entriesByDestination,
  }) : passports = Map.unmodifiable(passports),
       destinations = Map.unmodifiable(destinations),
       _entriesByDestination = Map.unmodifiable({
         for (final entry in entriesByDestination.entries)
           entry.key: Map<String, EntryRequirement>.unmodifiable(entry.value),
       });

  final DatasetMetadata metadata;
  final Map<String, Passport> passports;
  final Map<String, Destination> destinations;
  final Map<String, Map<String, EntryRequirement>> _entriesByDestination;

  EntryRequirement requirement(String passportCode, String destinationCode) =>
      _entriesByDestination[destinationCode]?[passportCode] ??
      EntryRequirement(
        passportCode: passportCode,
        destinationCode: destinationCode,
        type: RequirementType.unconfirmed,
        datasetVersion: metadata.version,
      );
}
