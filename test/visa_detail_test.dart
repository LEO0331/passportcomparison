import 'package:flutter_test/flutter_test.dart';

// Inline the function under test (mirrors visa_detail.dart)
Map<String, List<String>> generateComparisonMatrix(
  List<String> allCountryNames,
  Map<String, Set<String>> visaFreeSets,
) {
  Map<String, List<String>> matrix = {};
  for (var targetCountry in allCountryNames) {
    List<String> statuses = [];
    for (var passportName in visaFreeSets.keys) {
      bool isFree = visaFreeSets[passportName]!.contains(targetCountry);
      statuses.add(isFree ? "FREE" : "REQUIRED");
    }
    matrix[targetCountry] = statuses;
  }
  return matrix;
}

void main() {
  group('generateComparisonMatrix', () {
    test('returns FREE when destination is in visa-free set', () {
      final countries = ['France', 'China'];
      final visaFreeSets = {
        'Japan': {'France', 'Germany'},
      };

      final result = generateComparisonMatrix(countries, visaFreeSets);

      expect(result['France'], ['FREE']);
      expect(result['China'], ['REQUIRED']);
    });

    test('generates correct matrix for multiple passports', () {
      final countries = ['France', 'China', 'Brazil'];
      final visaFreeSets = {
        'Japan': {'France', 'Brazil'},
        'USA': {'France', 'China'},
      };

      final result = generateComparisonMatrix(countries, visaFreeSets);

      // France: both free
      expect(result['France'], ['FREE', 'FREE']);
      // China: Japan=REQUIRED, USA=FREE
      expect(result['China'], ['REQUIRED', 'FREE']);
      // Brazil: Japan=FREE, USA=REQUIRED
      expect(result['Brazil'], ['FREE', 'REQUIRED']);
    });

    test('returns empty matrix when no countries provided', () {
      final result = generateComparisonMatrix([], {'Japan': {'France'}});
      expect(result, isEmpty);
    });

    test('each country entry has correct number of status columns', () {
      final countries = ['A', 'B'];
      final visaFreeSets = {
        'P1': {'A'},
        'P2': {'B'},
        'P3': <String>{},
      };

      final result = generateComparisonMatrix(countries, visaFreeSets);

      // 3 passports → 3 status entries per destination
      expect(result['A']!.length, 3);
      expect(result['B']!.length, 3);
    });

    test('all REQUIRED when visa-free sets are empty', () {
      final countries = ['France', 'Japan'];
      final visaFreeSets = {
        'CountryA': <String>{},
        'CountryB': <String>{},
      };

      final result = generateComparisonMatrix(countries, visaFreeSets);

      expect(result['France'], ['REQUIRED', 'REQUIRED']);
      expect(result['Japan'], ['REQUIRED', 'REQUIRED']);
    });

    test('returns empty statuses per row when no passports provided', () {
      final countries = ['France'];
      final result = generateComparisonMatrix(countries, {});

      expect(result['France'], []);
    });

    test('matrix keys match provided country list', () {
      final countries = ['Germany', 'Brazil', 'India'];
      final visaFreeSets = {'JP': <String>{}};

      final result = generateComparisonMatrix(countries, visaFreeSets);

      expect(result.keys.toSet(), {'Germany', 'Brazil', 'India'});
    });
  });
}
