import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/country.dart';
import 'package:logger/logger.dart';

class ApiService {
  static const String baseUrl = "https://api.henleypassportindex.com/api/v3";
  static const Duration _requestTimeout = Duration(seconds: 12);
  final _logger = Logger();
  final http.Client client;
  final Future<String> Function() localCountriesLoader;

  ApiService({
    http.Client? client,
    Future<String> Function()? localCountriesLoader,
  }) : client = client ?? http.Client(),
       localCountriesLoader =
           localCountriesLoader ??
           (() => rootBundle.loadString('lib/data.json'));

  void _logInfo(String message) {
    if (kDebugMode) {
      _logger.i(message);
    }
  }

  void _logWarn(String message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      _logger.w(message, error: error, stackTrace: stackTrace);
    } else {
      _logger.w(message);
    }
  }

  void _logError(String message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      _logger.e(message, error: error, stackTrace: stackTrace);
    } else {
      _logger.e(message);
    }
  }

  List<Country> _parseCountriesPayload(String payload, String source) {
    try {
      final decoded = json.decode(payload);
      if (decoded is! Map<String, dynamic>) {
        _logWarn("Invalid country payload from $source: root is not a map");
        return [];
      }

      final countries = decoded['countries'];
      if (countries is! List) {
        _logWarn(
          "Invalid country payload from $source: 'countries' is missing or not a list",
        );
        return [];
      }

      return countries
          .whereType<Map<String, dynamic>>()
          .map(Country.fromJson)
          .toList();
    } catch (e, stackTrace) {
      _logWarn(
        "Failed to parse countries from $source",
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  // 獲取所有國家清單 (一進入頁面就呼叫)
  Future<List<Country>> fetchCountries() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final response = await client
          .get(Uri.parse('$baseUrl/countries'))
          .timeout(_requestTimeout);
      if (response.statusCode == 200) {
        final countries = _parseCountriesPayload(response.body, "API response");
        if (countries.isNotEmpty) {
          await prefs.setString('cached_countries', response.body);
          return countries;
        }
        _logWarn("API returned 200 but no usable countries");
      } else {
        _logWarn("API error: ${response.statusCode}");
      }
    } on TimeoutException catch (e, stackTrace) {
      _logWarn(
        "Request timeout: Loading fallback countries",
        error: e,
        stackTrace: stackTrace,
      );
    } catch (e, stackTrace) {
      _logWarn(
        "Network error: Loading fallback countries",
        error: e,
        stackTrace: stackTrace,
      );
    }

    final String? cached = prefs.getString('cached_countries');
    if (cached != null) {
      final cachedCountries = _parseCountriesPayload(cached, "cache");
      if (cachedCountries.isNotEmpty) {
        return cachedCountries;
      }
      _logWarn("Cached countries exist but are not usable");
    }

    try {
      final localPayload = await localCountriesLoader();
      final localCountries = _parseCountriesPayload(localPayload, "local data");
      if (localCountries.isNotEmpty) {
        _logWarn("Using local fallback dataset from lib/data.json");
        return localCountries;
      }
    } catch (e, stackTrace) {
      _logWarn(
        "Failed to load local fallback dataset",
        error: e,
        stackTrace: stackTrace,
      );
    }

    return [];
  }

  // 獲取特定國家的詳細准入代碼 (按下 Details 時呼叫)
  final Map<String, Set<String>> _cache = {};
  Future<Set<String>> fetchVisaFreeCodes(String countryCode) async {
    if (_cache.containsKey(countryCode)) {
      _logInfo("Returning cached data for: $countryCode");
      return _cache[countryCode]!;
    }
    try {
      final response = await client
          .get(Uri.parse('$baseUrl/visa-single/$countryCode'))
          .timeout(_requestTimeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        Set<String> codes = {};
        // 將免簽、落地簽、電子簽皆視為可准入 (可依需求細分)
        for (var category in [
          'visa_free_access',
          'visa_on_arrival',
          'visa_online',
        ]) {
          if (data[category] != null) {
            for (var item in data[category]) {
              codes.add(item['code']);
            }
          }
        }
        _cache[countryCode] = codes;
        return codes;
      }
    } on TimeoutException catch (e, stackTrace) {
      _logError(
        "Timeout fetching visa details",
        error: e,
        stackTrace: stackTrace,
      );
    } catch (e, stackTrace) {
      _logError(
        "Error fetching visa details",
        error: e,
        stackTrace: stackTrace,
      );
    }
    return {};
  }
}
