import 'package:flutter_test/flutter_test.dart';
import 'package:passportcomparison/models/comparison_access.dart';

void main() {
  group('Visa Comparison Logic', () {
    final Map<String, Set<String>> mockVisaMap = {
      'TW': {'JP', 'US', 'UK'},
      'SG': {'JP', 'CN', 'UK'},
    };
    final activeCodes = ['TW', 'SG'];

    test('Identify different visa requirements', () {
      expect(
        hasDifferentAccess(
          passportCodes: activeCodes,
          destinationCode: 'JP',
          visaFreeMap: mockVisaMap,
        ),
        isFalse,
      ); // 兩國都有免簽
      expect(
        hasDifferentAccess(
          passportCodes: activeCodes,
          destinationCode: 'US',
          visaFreeMap: mockVisaMap,
        ),
        isTrue,
      ); // 只有 TW 有
      expect(
        hasDifferentAccess(
          passportCodes: activeCodes,
          destinationCode: 'CN',
          visaFreeMap: mockVisaMap,
        ),
        isTrue,
      ); // 只有 SG 有
      expect(
        hasDifferentAccess(
          passportCodes: activeCodes,
          destinationCode: 'FR',
          visaFreeMap: mockVisaMap,
        ),
        isFalse,
      ); // 兩國都沒有 (均為 false)
    });
  });
}
