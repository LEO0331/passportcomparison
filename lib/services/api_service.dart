import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/country.dart';
import 'package:logger/logger.dart';

class ApiService {
  static const String baseUrl = "https://api.henleypassportindex.com/api/v3";
  final _logger = Logger();
  final http.Client client;
  ApiService({http.Client? client}) : client = client ?? http.Client();
  // 獲取所有國家清單 (一進入頁面就呼叫)
  Future<List<Country>> fetchCountries() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final response = await client.get(Uri.parse('$baseUrl/countries'));
      if (response.statusCode == 200) {
        await prefs.setString('cached_countries', response.body);
        final List<dynamic> data = json.decode(response.body)['countries'];
        return data.map((c) => Country.fromJson(c)).toList();
      } else {
        _logger.w("API error: ${response.statusCode}");
      }
    } catch (e) {
      _logger.w("Offline mode: Loading cached countries");
      final String? cached = prefs.getString('cached_countries');
      if (cached != null) {
        final List<dynamic> data = json.decode(cached)['countries'];
        return data.map((c) => Country.fromJson(c)).toList();
      }
    }
    return [];
  }

  // 獲取特定國家的詳細准入代碼 (按下 Details 時呼叫)
  Future<Set<String>> fetchVisaFreeCodes(String countryCode) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/visa-single/$countryCode'),
      );
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
        return codes;
      }
    } catch (e, stackTrace) {
      _logger.e(
        "Error fetching visa details",
        error: e,
        stackTrace: stackTrace,
      );
    }
    return {};
  }
}
