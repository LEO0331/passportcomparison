import 'package:flutter_test/flutter_test.dart';
import 'package:passportcomparison/models/comparison_session.dart';

void main() {
  group('ComparisonSession', () {
    test('tracks active selections and completion state', () {
      var session = ComparisonSession.empty(defaultYear: '2024');

      expect(session.hasAnySelected, isFalse);
      expect(session.hasAllSelected, isFalse);
      expect(session.activeCodes, isEmpty);

      session = session.updateCountry(0, 'TW').updateCountry(1, 'JP');

      expect(session.hasAnySelected, isTrue);
      expect(session.hasAllSelected, isTrue);
      expect(session.activeCodes, ['TW', 'JP']);
    });

    test('serializes favorite snapshot and preserves custom title', () {
      final session = ComparisonSession.empty(
        defaultYear: '2024',
      ).updateCountry(0, 'TW').updateCountry(1, 'JP').updateYear(1, '2023');

      final snapshot = session.toFavoriteSnapshot(
        title: 'My Trip',
        date: '2026-05-15 10:00',
      );

      final json = snapshot.toJson();

      expect(json['title'], 'My Trip');
      expect(json['count'], 2);
      expect(json['codes'], ['TW', 'JP', null, null, null]);
      expect(json['years'], ['2024', '2023', '2024', '2024', '2024']);
    });
  });

  group('FavoriteSnapshot', () {
    test('hydrates shorter saved lists into padded selections', () {
      final snapshot = FavoriteSnapshot.fromJson({
        'title': 'Saved Pair',
        'date': '2026-05-15 10:00',
        'codes': ['TW', 'JP'],
        'years': ['2024'],
        'count': 2,
      }, fallbackYear: '2026');

      expect(snapshot.title, 'Saved Pair');
      expect(snapshot.activeCodes, ['TW', 'JP']);
      expect(snapshot.selections.length, 5);
      expect(snapshot.selections[0].year, '2024');
      expect(snapshot.selections[1].year, '2026');
      expect(snapshot.selections[2].countryCode, isNull);
    });
  });
}
