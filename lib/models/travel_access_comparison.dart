import 'entry_requirements.dart';

enum ComparisonFilter { all, differences, visaFreeDifferences }

class DestinationComparison {
  DestinationComparison({
    required this.destination,
    required List<EntryRequirement> requirements,
  }) : requirements = List.unmodifiable(requirements);

  final Destination destination;
  final List<EntryRequirement> requirements;

  bool get hasUnknown =>
      requirements.any((requirement) => requirement.isUnknown);
  bool get hasCategoryDifference =>
      requirements
          .where((requirement) => !requirement.isUnknown)
          .map((requirement) => requirement.type)
          .toSet()
          .length >
      1;

  bool get hasVisaFreeDifference =>
      requirements.any((requirement) => requirement.confirmedVisaFree) &&
      requirements.any(_knownNonVisaFree);

  bool get allRequireAdvanceAuthorization => requirements.every(
    (requirement) => requirement.type.isAdvanceAuthorization,
  );
}

bool _knownNonVisaFree(EntryRequirement requirement) =>
    !requirement.isUnknown && requirement.type != RequirementType.visaFree;

class TravelAccessComparison {
  TravelAccessComparison._({
    required this.metadata,
    required this.passports,
    required this.rows,
    required this.sharedVisaFree,
    required this.combinedVisaFree,
    required this.differentCategories,
    required this.unknown,
    required this.visaFreeDifferences,
    required this.visaFreeOnlyByPassport,
  });

  factory TravelAccessComparison.calculate(
    PassportDataset dataset,
    List<String> passportCodes,
  ) {
    final selectedCodes = passportCodes.toSet();
    if (selectedCodes.length != passportCodes.length ||
        selectedCodes.length < 2 ||
        selectedCodes.length > 5 ||
        !selectedCodes.every(dataset.passports.containsKey)) {
      throw ArgumentError('Select two to five distinct supported passports');
    }

    final passports = [
      for (final code in passportCodes) dataset.passports[code]!,
    ];
    // Count only destinations that are international for every participant.
    final destinations =
        dataset.destinations.values
            .where((destination) => !selectedCodes.contains(destination.code))
            .toList()
          ..sort((a, b) {
            final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
            return byName != 0 ? byName : a.code.compareTo(b.code);
          });
    final rows = [
      for (final destination in destinations)
        DestinationComparison(
          destination: destination,
          requirements: [
            for (final code in passportCodes)
              dataset.requirement(code, destination.code),
          ],
        ),
    ];

    var shared = 0;
    var combined = 0;
    var different = 0;
    var unknown = 0;
    var visaFreeDifferences = 0;
    final onlyByPassport = {for (final code in passportCodes) code: 0};
    for (final row in rows) {
      final visaFree = row.requirements
          .where((requirement) => requirement.confirmedVisaFree)
          .toList();
      if (visaFree.length == passports.length) shared++;
      if (visaFree.isNotEmpty) combined++;
      if (row.hasCategoryDifference) different++;
      if (row.hasUnknown) unknown++;
      if (row.hasVisaFreeDifference) visaFreeDifferences++;
      if (visaFree.length == 1 &&
          row.requirements.every(
            (requirement) =>
                requirement.confirmedVisaFree || _knownNonVisaFree(requirement),
          )) {
        final code = visaFree.single.passportCode;
        onlyByPassport[code] = onlyByPassport[code]! + 1;
      }
    }

    return TravelAccessComparison._(
      metadata: dataset.metadata,
      passports: List.unmodifiable(passports),
      rows: List.unmodifiable(rows),
      sharedVisaFree: shared,
      combinedVisaFree: combined,
      differentCategories: different,
      unknown: unknown,
      visaFreeDifferences: visaFreeDifferences,
      visaFreeOnlyByPassport: Map.unmodifiable(onlyByPassport),
    );
  }

  final DatasetMetadata metadata;
  final List<Passport> passports;
  final List<DestinationComparison> rows;
  final int sharedVisaFree;
  final int combinedVisaFree;
  final int differentCategories;
  final int unknown;
  final int visaFreeDifferences;
  final Map<String, int> visaFreeOnlyByPassport;

  List<DestinationComparison> filteredRows({
    ComparisonFilter filter = ComparisonFilter.all,
    String? region,
    String query = '',
    String locale = 'en',
  }) {
    final search = query.trim().toLowerCase();
    return rows.where((row) {
      final destination = row.destination;
      if (region != null && destination.region != region) return false;
      if (search.isNotEmpty &&
          !destination.name.toLowerCase().contains(search) &&
          !destination.nameFor(locale).toLowerCase().contains(search) &&
          destination.code.toLowerCase() != search) {
        return false;
      }
      return switch (filter) {
        ComparisonFilter.all => true,
        ComparisonFilter.differences => row.hasCategoryDifference,
        ComparisonFilter.visaFreeDifferences => row.hasVisaFreeDifference,
      };
    }).toList();
  }
}
