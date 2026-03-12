import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:passportcomparison/services/api_service.dart';
import 'package:passportcomparison/models/country.dart';

import 'api_service_test.mocks.dart';

@GenerateMocks([http.Client])
void main() {
  late MockClient mockClient;
  late ApiService service;

  setUp(() {
    mockClient = MockClient();
    service = ApiService(client: mockClient);
    // Use in-memory SharedPreferences for all tests
    SharedPreferences.setMockInitialValues({});
  });

  // ---------------------------------------------------------------------------
  // fetchCountries
  // ---------------------------------------------------------------------------
  group('ApiService.fetchCountries', () {
    final validResponseBody = jsonEncode({
      'countries': [
        {
          'code': 'JP',
          'country': 'Japan',
          'region': 'Asia',
          'openness': 92.5,
          'has_data': true,
          'data': {'2024': 193},
        },
        {
          'code': 'DE',
          'country': 'Germany',
          'region': 'Europe',
          'openness': 90.0,
          'has_data': true,
          'data': {},
        },
      ],
    });

    test('returns parsed countries on HTTP 200', () async {
      when(mockClient.get(any)).thenAnswer(
        (_) async => http.Response(validResponseBody, 200),
      );

      final countries = await service.fetchCountries();

      expect(countries.length, 2);
      expect(countries[0].code, 'JP');
      expect(countries[0].name, 'Japan');
      expect(countries[1].code, 'DE');
    });

    test('returns empty list on non-200 status', () async {
      when(mockClient.get(any)).thenAnswer(
        (_) async => http.Response('Not found', 404),
      );

      final countries = await service.fetchCountries();
      expect(countries, isEmpty);
    });

    test('returns cached countries when network throws', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_countries', validResponseBody);

      when(mockClient.get(any)).thenThrow(Exception('No internet'));

      final countries = await service.fetchCountries();
      expect(countries.length, 2);
      expect(countries[0].code, 'JP');
    });

    test('returns empty list when network throws and no cache exists', () async {
      when(mockClient.get(any)).thenThrow(Exception('No internet'));

      final countries = await service.fetchCountries();
      expect(countries, isEmpty);
    });

    test('caches response body after successful fetch', () async {
      when(mockClient.get(any)).thenAnswer(
        (_) async => http.Response(validResponseBody, 200),
      );

      await service.fetchCountries();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('cached_countries'), validResponseBody);
    });
  });

  // ---------------------------------------------------------------------------
  // fetchVisaFreeCodes
  // ---------------------------------------------------------------------------
  group('ApiService.fetchVisaFreeCodes', () {
    final visaResponse = jsonEncode({
      'visa_free_access': [
        {'code': 'FR'},
        {'code': 'DE'},
      ],
      'visa_on_arrival': [
        {'code': 'TH'},
      ],
      'visa_online': [
        {'code': 'IN'},
      ],
    });

    test('returns correct set of codes from all three categories', () async {
      when(mockClient.get(any)).thenAnswer(
        (_) async => http.Response(visaResponse, 200),
      );

      final codes = await service.fetchVisaFreeCodes('JP');
      expect(codes, containsAll(['FR', 'DE', 'TH', 'IN']));
      expect(codes.length, 4);
    });

    test('returns cached result on second call without HTTP request', () async {
      when(mockClient.get(any)).thenAnswer(
        (_) async => http.Response(visaResponse, 200),
      );

      await service.fetchVisaFreeCodes('JP');
      await service.fetchVisaFreeCodes('JP'); // second call → should use cache

      // HTTP client should only have been called once
      verify(mockClient.get(any)).called(1);
    });

    test('returns empty set on network error', () async {
      when(mockClient.get(any)).thenThrow(Exception('timeout'));

      final codes = await service.fetchVisaFreeCodes('XX');
      expect(codes, isEmpty);
    });

    test('returns empty set on non-200 response', () async {
      when(mockClient.get(any)).thenAnswer(
        (_) async => http.Response('error', 500),
      );

      final codes = await service.fetchVisaFreeCodes('XX');
      expect(codes, isEmpty);
    });

    test('handles missing categories gracefully', () async {
      final partialResponse = jsonEncode({
        'visa_free_access': [
          {'code': 'FR'},
        ],
        // visa_on_arrival and visa_online missing
      });

      when(mockClient.get(any)).thenAnswer(
        (_) async => http.Response(partialResponse, 200),
      );

      final codes = await service.fetchVisaFreeCodes('US');
      expect(codes, {'FR'});
    });

    test('caches results per country code independently', () async {
      final jpResponse = jsonEncode({
        'visa_free_access': [
          {'code': 'FR'},
        ],
        'visa_on_arrival': [],
        'visa_online': [],
      });
      final deResponse = jsonEncode({
        'visa_free_access': [
          {'code': 'BR'},
        ],
        'visa_on_arrival': [],
        'visa_online': [],
      });

      when(
        mockClient.get(Uri.parse('https://api.henleypassportindex.com/api/v3/visa-single/JP')),
      ).thenAnswer((_) async => http.Response(jpResponse, 200));

      when(
        mockClient.get(Uri.parse('https://api.henleypassportindex.com/api/v3/visa-single/DE')),
      ).thenAnswer((_) async => http.Response(deResponse, 200));

      final jpCodes = await service.fetchVisaFreeCodes('JP');
      final deCodes = await service.fetchVisaFreeCodes('DE');

      expect(jpCodes, {'FR'});
      expect(deCodes, {'BR'});
    });
  });
}
