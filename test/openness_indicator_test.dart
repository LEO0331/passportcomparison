import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passportcomparison/widgets/openness_indicator.dart';

void main() {
  Widget buildWidget(double score) {
    return MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: OpennessIndicator(score: score),
        ),
      ),
    );
  }

  group('OpennessIndicator', () {
    testWidgets('renders "Openness" label', (tester) async {
      await tester.pumpWidget(buildWidget(50));
      expect(find.text('Openness'), findsOneWidget);
    });

    testWidgets('displays score value formatted to 1 decimal place', (tester) async {
      await tester.pumpWidget(buildWidget(75.123));
      expect(find.text('75.1'), findsOneWidget);
    });

    testWidgets('displays 0.0 score correctly', (tester) async {
      await tester.pumpWidget(buildWidget(0));
      expect(find.text('0.0'), findsOneWidget);
    });

    testWidgets('displays 100.0 score correctly', (tester) async {
      await tester.pumpWidget(buildWidget(100));
      expect(find.text('100.0'), findsOneWidget);
    });

    testWidgets('renders LinearProgressIndicator', (tester) async {
      await tester.pumpWidget(buildWidget(60));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('score > 70 uses green color for text', (tester) async {
      await tester.pumpWidget(buildWidget(80));
      await tester.pump();

      final textWidgets = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => t.data == '80.0')
          .toList();

      expect(textWidgets.isNotEmpty, true);
      final style = textWidgets.first.style;
      expect(style?.color, Colors.green);
    });

    testWidgets('score between 30 and 70 uses orange color', (tester) async {
      await tester.pumpWidget(buildWidget(50));
      await tester.pump();

      final textWidgets = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => t.data == '50.0')
          .toList();

      expect(textWidgets.isNotEmpty, true);
      expect(textWidgets.first.style?.color, Colors.orange);
    });

    testWidgets('score <= 30 uses red color', (tester) async {
      await tester.pumpWidget(buildWidget(20));
      await tester.pump();

      final textWidgets = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => t.data == '20.0')
          .toList();

      expect(textWidgets.isNotEmpty, true);
      expect(textWidgets.first.style?.color, Colors.red);
    });

    testWidgets('progress bar value equals score / 100', (tester) async {
      await tester.pumpWidget(buildWidget(65));
      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, closeTo(0.65, 0.001));
    });

    testWidgets('custom height is applied', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OpennessIndicator(score: 50, height: 16),
          ),
        ),
      );
      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.minHeight, 16);
    });

    testWidgets('default height is 8', (tester) async {
      await tester.pumpWidget(buildWidget(50));
      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.minHeight, 8);
    });
  });
}
