import '../models/bible_verse.dart';
import '../utils/number_words.dart';
import '../utils/bible_books.dart';

/// Scans transcribed speech for Bible verse references.
///
/// Handles all of these patterns:
///   "John 3:16"
///   "John 3 16"
///   "John three sixteen"
///   "John chapter three verse sixteen"
///   "John three, sixteen"   (with punctuation)
///   "1 Corinthians 13:4"
///   "First Corinthians thirteen four"
///   "Second Kings chapter seven verse three"
class VerseDetector {
  // Noise words that sit between book name and chapter/verse numbers.
  static final _noise = RegExp(
    r'\b(chapter|verse|verses|and|the|of|to|at|in|from|a|an)\b',
    caseSensitive: false,
  );

  /// Detects the first valid Bible verse reference in [rawText].
  /// Returns null if none is found.
  static VerseReference? detect(String rawText) {
    if (rawText.trim().isEmpty) return null;

    // 1. Convert number words to digits ("three" → "3")
    final normalized = NumberWords.convert(rawText.toLowerCase());

    // 2. Scan for every known book label (longest first to avoid prefix clashes)
    for (final label in BibleBooks.sortedKeys) {
      final idx = normalized.indexOf(label);
      if (idx == -1) continue;

      // Make sure the label is a whole word / phrase (not inside another word)
      final before = idx > 0 ? normalized[idx - 1] : ' ';
      final after = idx + label.length < normalized.length
          ? normalized[idx + label.length]
          : ' ';
      if (RegExp(r'[a-z]').hasMatch(before)) continue;
      if (RegExp(r'[a-z]').hasMatch(after)) continue;

      final canonicalBook = BibleBooks.resolve(label)!;

      // 3. Take the text after the book name, strip noise words
      final tail = normalized.substring(idx + label.length);
      final cleaned = tail
          .replaceAll(_noise, ' ')
          .replaceAll(RegExp(r'[^0-9\s]'), ' ') // keep only digits + spaces
          .trim();

      // 4. Extract up to 2 numbers
      final numbers = RegExp(r'\d+').allMatches(cleaned).toList();

      if (numbers.length >= 2) {
        final chapter = int.tryParse(numbers[0].group(0)!);
        final verse = int.tryParse(numbers[1].group(0)!);
        if (chapter != null && verse != null && chapter > 0 && verse > 0) {
          return VerseReference(book: canonicalBook, chapter: chapter, verse: verse);
        }
      }

      // Only one number found — treat as chapter 1, verse N
      // (e.g. pastor says "Psalms 23" meaning Psalm 23:1)
      if (numbers.length == 1) {
        final chapter = int.tryParse(numbers[0].group(0)!);
        if (chapter != null && chapter > 0) {
          return VerseReference(book: canonicalBook, chapter: chapter, verse: 1);
        }
      }
    }

    return null;
  }
}
