import 'package:flutter_test/flutter_test.dart';
import 'package:paragon_pro/core/utils/duplicate_detector.dart';

void main() {
  group('DuplicateDetector.normalize', () {
    test('lowercases and strips non-alphanumerics', () {
      expect(
        DuplicateDetector.normalize('  Z 7930 EnBeeS!! '),
        'z7930enbees',
      );
    });

    test('empty input returns empty', () {
      expect(DuplicateDetector.normalize('  ???  '), '');
    });
  });

  group('DuplicateDetector.distance', () {
    test('equal strings have distance 0', () {
      expect(DuplicateDetector.distance('abc', 'abc'), 0);
    });

    test('single substitution = 1', () {
      expect(DuplicateDetector.distance('cat', 'bat'), 1);
    });

    test('insertions and deletions counted', () {
      expect(DuplicateDetector.distance('kitten', 'sitting'), 3);
    });
  });

  group('DuplicateDetector.extractSerialTokens', () {
    test('picks alphanumeric runs that mix digits and letters', () {
      expect(
        DuplicateDetector.extractSerialTokens('Lodówka Z7930 EnBeeS srvc'),
        containsAll({'Z7930'}),
      );
    });

    test('ignores pure digit and pure letter runs', () {
      expect(
        DuplicateDetector.extractSerialTokens('123456 abcdef'),
        isEmpty,
      );
    });
  });

  group('DuplicateDetector.isDuplicate', () {
    test('regression: Z7930 EnBeeS variants flagged', () {
      expect(
        DuplicateDetector.isDuplicate(
          'Lodówka Z7930 EnBeeS',
          'lodowka z7930 enbees',
        ),
        isTrue,
      );
    });

    test('shared serial number flags duplicate even if names differ', () {
      expect(
        DuplicateDetector.isDuplicate(
          'Pralka model X (SN12345A)',
          'My washing machine SN12345A',
        ),
        isTrue,
      );
    });

    test('distinct items not flagged', () {
      expect(
        DuplicateDetector.isDuplicate(
          'Lodówka Z7930 EnBeeS',
          'Pralka XYZ9999',
        ),
        isFalse,
      );
    });

    test('empty input never flags', () {
      expect(DuplicateDetector.isDuplicate('', 'anything'), isFalse);
      expect(DuplicateDetector.isDuplicate('anything', ''), isFalse);
    });
  });
}
