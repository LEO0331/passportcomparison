import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Visa Comparison Logic', () {
    final Map<String, Set<String>> mockVisaMap = {
      'TW': {'JP', 'US', 'UK'},
      'SG': {'JP', 'CN', 'UK'},
    };
    final activeCodes = ['TW', 'SG'];

    test('Identify different visa requirements', () {
      // 邏輯：如果某目的地在兩國待遇不同，則回傳 true
      bool hasDifference(String dest) {
        final results = activeCodes
            .map((c) => mockVisaMap[c]!.contains(dest))
            .toList();
        return !results.every((r) => r == results.first);
      }

      expect(hasDifference('JP'), isFalse); // 兩國都有免簽
      expect(hasDifference('US'), isTrue); // 只有 TW 有
      expect(hasDifference('CN'), isTrue); // 只有 SG 有
      expect(hasDifference('FR'), isFalse); // 兩國都沒有 (均為 false)
    });
  });
}
