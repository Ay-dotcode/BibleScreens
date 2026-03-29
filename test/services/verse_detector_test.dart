import 'package:bible_screens/models/bible_verse.dart';
import 'package:bible_screens/services/verse_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VerseDetector', () {
    VerseReference expectRef(String text) {
      final result = VerseDetector.detect(text);
      expect(result, isNotNull, reason: 'Expected a verse for: $text');
      return result!;
    }

    test('detects chapter and verse from plain digits', () {
      final ref = expectRef('please open john 3 5 right now');
      expect(ref.book, 'John');
      expect(ref.chapter, 3);
      expect(ref.verse, 5);
    });

    test('detects chapter and verse from number words', () {
      final ref = expectRef('let us read john three five together');
      expect(ref.book, 'John');
      expect(ref.chapter, 3);
      expect(ref.verse, 5);
    });

    test('detects references with chapter verse words', () {
      final ref = expectRef('second kings chapter seven verse three');
      expect(ref.book, '2 Kings');
      expect(ref.chapter, 7);
      expect(ref.verse, 3);
    });

    test('defaults to verse 1 when only chapter is spoken', () {
      final ref = expectRef('psalms twenty three');
      expect(ref.book, 'Psalms');
      expect(ref.chapter, 23);
      expect(ref.verse, 1);
    });

    test('prefers the latest valid reference in one transcript', () {
      final ref = expectRef('john 3 16 then romans 8 28');
      expect(ref.book, 'Romans');
      expect(ref.chapter, 8);
      expect(ref.verse, 28);
    });

    test('returns null when no reference exists', () {
      expect(VerseDetector.detect('hallelujah amen everyone'), isNull);
    });

    test('detects verse range with colon separator', () {
      final intent = VerseDetector.detectIntent('genesis 1:3-6');
      expect(intent, isA<VerseRangeIntent>());
      final range = intent as VerseRangeIntent;
      expect(range.start.book, 'Genesis');
      expect(range.start.chapter, 1);
      expect(range.start.verse, 3);
      expect(range.endVerse, 6);
    });

    test('detects verse range with space separator', () {
      final intent = VerseDetector.detectIntent('genesis 1 3 to 6');
      expect(intent, isA<VerseRangeIntent>());
      final range = intent as VerseRangeIntent;
      expect(range.start.book, 'Genesis');
      expect(range.start.chapter, 1);
      expect(range.start.verse, 3);
      expect(range.endVerse, 6);
    });
  });
}
