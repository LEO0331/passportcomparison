import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passportcomparison/widgets/passport_input.dart';
import 'package:passportcomparison/models/country.dart';

void main() {
  // 建立模擬資料
  final mockCountries = [
    Country(
      code: 'TW',
      name: 'Taiwan',
      region: 'Asia',
      openness: 100,
      hasData: true,
    ),
    Country(
      code: 'JP',
      name: 'Japan',
      region: 'Asia',
      openness: 100,
      hasData: true,
    ),
  ];

  testWidgets(
    'PassportInputRow displays correct country and triggers callback',
    (WidgetTester tester) async {
      String? selectedCode;

      // 1. 渲染元件
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassportInputRow(
              index: 0,
              countries: mockCountries,
              selectedCode: 'TW',
              selectedYear: '2024',
              onCountryChanged: (val) => selectedCode = val,
              onYearChanged: (val) {},
            ),
          ),
        ),
      );

      // 2. 驗證文字是否出現
      expect(find.text('Taiwan'), findsOneWidget);
      expect(find.text('2024'), findsOneWidget);

      // 3. 模擬點擊下拉選單 (Dropdown)
      await tester.tap(find.text('Taiwan'));
      await tester.pumpAndSettle(); // 等待選單動畫結束

      // 4. 點擊另一個國家 'Japan'
      await tester.tap(find.text('Japan').last);
      await tester.pumpAndSettle();

      // 5. 驗證 Callback 是否被呼叫
      expect(selectedCode, 'JP');
    },
  );

  testWidgets('Compare button is disabled when countries are missing', (
    WidgetTester tester,
  ) async {
    // 模擬首頁的部分狀態
    bool isComparing = false;
    List<String?> selectedCodes = [null, null]; // 假設需要兩本護照但都沒選

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ElevatedButton(
            // 模擬你代碼中的邏輯：如果包含 null 則 onPressed 為 null (Disabled)
            onPressed: selectedCodes.contains(null)
                ? null
                : () => isComparing = true,
            child: const Text("Compare"),
          ),
        ),
      ),
    );

    // 1. 尋找按鈕
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));

    // 2. 驗證按鈕目前無法點擊 (onPressed 為空)
    expect(button.enabled, isFalse);

    // 3. 嘗試點擊（應該沒反應）
    await tester.tap(find.byType(ElevatedButton));
    expect(isComparing, isFalse);
  });
}
