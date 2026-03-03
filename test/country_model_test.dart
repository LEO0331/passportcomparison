import 'package:flutter_test/flutter_test.dart';
import 'package:passportcomparison/models/country.dart';

void main() {
  group('Country Model Parsing', () {
    test('Should parse full JSON with yearly data', () {
      final json = {
        "code": "TW",
        "country": "Taiwan",
        "region": "East Asia",
        "openness": 143.0,
        "has_data": true,
        "data": {
          "2024": {"rank": 35, "total": 143},
        },
      };
      final country = Country.fromJson(json);
      expect(country.code, 'TW');
      expect(country.yearlyData?['2024']['rank'], 35);
    });

    test('Should handle missing data field safely', () {
      final json = {"code": "XX", "has_data": false};
      final country = Country.fromJson(json);
      expect(country.name, 'Unknown');
      expect(country.yearlyData, isNull);
    });
  });
}
