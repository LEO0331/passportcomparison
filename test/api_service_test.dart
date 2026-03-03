import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 1. 引入這行
import 'package:passportcomparison/services/api_service.dart';

@GenerateMocks([http.Client])
import 'api_service_test.mocks.dart';

void main() {
  // 2. 關鍵：在 main() 的第一行初始化測試綁定
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockClient mockClient;
  late ApiService apiService;

  setUp(() {
    // 3. 關鍵：設定 SharedPreferences 的模擬初始值（即便為空也要設定）
    SharedPreferences.setMockInitialValues({}); 
    
    mockClient = MockClient();
    apiService = ApiService(client: mockClient);
  });

  group('ApiService Tests', () {
    test('fetchCountries returns List<Country> on 200', () async {
      // 模擬 API 回傳
      when(mockClient.get(any)).thenAnswer((_) async => http.Response(
        jsonEncode({
          "countries": [{"code": "TW", "country": "Taiwan", "has_data": false}]
        }), 200));

      final result = await apiService.fetchCountries();
      
      expect(result.first.code, 'TW');
      expect(result.first.name, 'Taiwan');
    });

    test('fetchCountries returns empty list on 404', () async {
      when(mockClient.get(any)).thenAnswer((_) async => http.Response('Not Found', 404));
      
      final result = await apiService.fetchCountries();
      
      expect(result, isEmpty);
    });
  });
}
