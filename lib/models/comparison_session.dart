class PassportSelection {
  final String? countryCode;
  final String year;

  const PassportSelection({required this.countryCode, required this.year});

  PassportSelection copyWith({Object? countryCode = _unset, String? year}) {
    return PassportSelection(
      countryCode: identical(countryCode, _unset)
          ? this.countryCode
          : countryCode as String?,
      year: year ?? this.year,
    );
  }
}

const Object _unset = Object();

class FavoriteSnapshot {
  final String title;
  final String date;
  final int count;
  final List<PassportSelection> selections;

  const FavoriteSnapshot({
    required this.title,
    required this.date,
    required this.count,
    required this.selections,
  });

  factory FavoriteSnapshot.fromJson(
    Map<String, dynamic> json, {
    required String fallbackYear,
    int slotCount = 5,
  }) {
    final rawCodes = (json['codes'] as List? ?? [])
        .map((value) => value?.toString())
        .toList();
    final rawYears = (json['years'] as List? ?? [])
        .map((value) => value?.toString() ?? fallbackYear)
        .toList();
    final selections = List.generate(slotCount, (index) {
      final code = index < rawCodes.length ? rawCodes[index] : null;
      final year = index < rawYears.length ? rawYears[index] : fallbackYear;
      return PassportSelection(countryCode: code, year: year);
    });

    final rawCount = json['count'];
    final parsedCount = rawCount is int
        ? rawCount
        : int.tryParse(rawCount?.toString() ?? '') ?? 1;

    return FavoriteSnapshot(
      title: (json['title']?.toString().trim().isNotEmpty ?? false)
          ? json['title'].toString()
          : 'Untitled Comparison',
      date: (json['date']?.toString().trim().isNotEmpty ?? false)
          ? json['date'].toString()
          : 'Unknown Date',
      count: parsedCount.clamp(1, slotCount),
      selections: selections,
    );
  }

  Map<String, dynamic> toJson({int slotCount = 5}) {
    final paddedSelections = [
      ...selections.take(slotCount),
      ...List.generate(
        slotCount - selections.take(slotCount).length,
        (_) => const PassportSelection(countryCode: null, year: ''),
      ),
    ];

    return {
      'title': title,
      'date': date,
      'codes': paddedSelections
          .map((selection) => selection.countryCode)
          .toList(),
      'years': paddedSelections.map((selection) => selection.year).toList(),
      'count': count,
    };
  }

  List<String> get activeCodes => selections
      .take(count)
      .map((selection) => selection.countryCode)
      .whereType<String>()
      .where((code) => code.isNotEmpty)
      .toList();
}

class ComparisonSession {
  final int passportCount;
  final List<PassportSelection> selections;

  const ComparisonSession({
    required this.passportCount,
    required this.selections,
  });

  factory ComparisonSession.empty({
    required String defaultYear,
    int passportCount = 2,
    int slotCount = 5,
  }) {
    return ComparisonSession(
      passportCount: passportCount,
      selections: List.generate(
        slotCount,
        (_) => PassportSelection(countryCode: null, year: defaultYear),
      ),
    );
  }

  ComparisonSession copyWith({
    int? passportCount,
    List<PassportSelection>? selections,
  }) {
    return ComparisonSession(
      passportCount: passportCount ?? this.passportCount,
      selections: selections ?? this.selections,
    );
  }

  ComparisonSession updatePassportCount(int count) {
    return copyWith(passportCount: count);
  }

  ComparisonSession updateCountry(int index, String? countryCode) {
    final nextSelections = List<PassportSelection>.from(selections);
    nextSelections[index] = nextSelections[index].copyWith(
      countryCode: countryCode,
    );
    return copyWith(selections: nextSelections);
  }

  ComparisonSession updateYear(int index, String year) {
    final nextSelections = List<PassportSelection>.from(selections);
    nextSelections[index] = nextSelections[index].copyWith(year: year);
    return copyWith(selections: nextSelections);
  }

  List<String> get activeCodes => selections
      .take(passportCount)
      .map((selection) => selection.countryCode)
      .whereType<String>()
      .where((code) => code.isNotEmpty)
      .toList();

  bool get hasAnySelected => selections
      .take(passportCount)
      .any((selection) => selection.countryCode != null);

  bool get hasAllSelected => selections
      .take(passportCount)
      .every((selection) => selection.countryCode != null);

  FavoriteSnapshot toFavoriteSnapshot({
    required String title,
    required String date,
  }) {
    return FavoriteSnapshot(
      title: title,
      date: date,
      count: passportCount,
      selections: List<PassportSelection>.from(selections),
    );
  }

  static ComparisonSession fromFavoriteSnapshot(FavoriteSnapshot snapshot) {
    return ComparisonSession(
      passportCount: snapshot.count,
      selections: List<PassportSelection>.from(snapshot.selections),
    );
  }
}
