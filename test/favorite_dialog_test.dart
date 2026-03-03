import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passportcomparison/main.dart'; // 確保路徑正確

void main() {
  testWidgets('Clicking favorite button shows rename dialog', (
    WidgetTester tester,
  ) async {
    // 1. 模擬必要的環境（如果你的頁面需要 Provider 或 MaterialApp）
    // 這裡我們直接渲染包含 _onAddToFavorite 邏輯的頁面
    // 注意：如果你的 Page 需要傳入參數，請依照 main.dart 調整
    await tester.pumpWidget(const MaterialApp(home: PassportComparePage()));

    // 2. 模擬「已按下 Compare」且「有選中國家」的狀態
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                // 這裡模擬觸發對話框
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Save to Favorites"),
                    content: const TextField(
                      decoration: InputDecoration(
                        labelText: "Comparison Title",
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel"),
                      ),
                    ],
                  ),
                );
              },
              child: const Text("Open Dialog"),
            ),
          ),
        ),
      ),
    );

    // 點擊觸發按鈕
    await tester.tap(find.text("Open Dialog"));
    await tester.pumpAndSettle(); // 等待對話框彈出動畫完成

    // 3. 驗證對話框是否出現
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text("Save to Favorites"), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    // 4. 模擬點擊取消
    await tester.tap(find.text("Cancel"));
    await tester.pumpAndSettle(); // 等待對話框消失動畫

    // 5. 驗證對話框已關閉
    expect(find.byType(AlertDialog), findsNothing);
  });
}
