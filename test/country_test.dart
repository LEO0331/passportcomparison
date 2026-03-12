import 'package:flutter_test/flutter_test.dart';
import 'package:passportcomparison/models/country.dart';

void main() {
  group('Country.fromJson', () {
    test('parses all fields correctly from a complete JSON object', () {
      final json = {
        'code': 'JP',
        'country': 'Japan',
        'region': 'Asia',
        'openness': 92.5,
        'has_data': true,
        'data': {'2024': 193, '2023': 189},
      };

      final country = Country.fromJson(json);

      expect(country.code, 'JP');
      expect(country.name, 'Japan');
      expect(country.region, 'Asia');
      expect(country.openness, 92.5);
      expect(country.hasData, true);
      expect(country.yearlyData, {'2024': 193, '2023': 189});
    });

    test('converts integer openness to double', () {
      final json = {
        'code': 'DE',
        'country': 'Germany',
        'region': 'Europe',
        'openness': 90, // int, not double
        'has_data': true,
        'data': {},
      };

      final country = Country.fromJson(json);
      expect(country.openness, isA<double>());
      expect(country.openness, 90.0);
    });

    test('sets yearlyData to null when has_data is false', () {
      final json = {
        'code': 'XX',
        'country': 'Unknown Country',
        'region': 'Unknown',
        'openness': 0.0,
        'has_data': false,
        'data': {'2024': 10},
      };

      final country = Country.fromJson(json);
      expect(country.hasData, false);
      expect(country.yearlyData, isNull);
    });

    test('sets yearlyData to null when data is not a Map', () {
      final json = {
        'code': 'XX',
        'country': 'Test',
        'region': 'Test',
        'openness': 50.0,
        'has_data': true,
        'data': 'not_a_map', // invalid type
      };

      final country = Country.fromJson(json);
      expect(country.yearlyData, isNull);
    });

    test('uses default values for missing fields', () {
      final country = Country.fromJson({});

      expect(country.code, '');
      expect(country.name, 'Unknown');
      expect(country.region, 'Unknown');
      expect(country.openness, 0.0);
      expect(country.hasData, false);
      expect(country.yearlyData, isNull);
    });

    test('handles null openness gracefully', () {
      final json = {
        'code': 'AB',
        'country': 'Alpha',
        'region': 'Beta',
        'has_data': false,
        'openness': null,
      };

      final country = Country.fromJson(json);
      expect(country.openness, 0.0);
    });

    test('direct constructor sets all fields', () {
      final country = Country(
        code: 'US',
        name: 'United States',
        region: 'Americas',
        openness: 85.0,
        hasData: true,
        yearlyData: {'2024': 186},
      );

      expect(country.code, 'US');
      expect(country.name, 'United States');
      expect(country.region, 'Americas');
      expect(country.openness, 85.0);
      expect(country.hasData, true);
      expect(country.yearlyData, {'2024': 186});
    });

    test('yearlyData defaults to null when not provided in constructor', () {
      final country = Country(
        code: 'FR',
        name: 'France',
        region: 'Europe',
        openness: 88.0,
        hasData: false,
      );

      expect(country.yearlyData, isNull);
    });
  });
}
