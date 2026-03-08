import '../models/bible_verse.dart';
import '../utils/bible_books.dart';
import '../utils/number_words.dart';

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

    // 2. Collect all possible book mentions and prefer the most recently spoken.
    final candidates = <_BookCandidate>[];
    for (final label in BibleBooks.sortedKeys) {
      final canonicalBook = BibleBooks.resolve(label);
      if (canonicalBook == null) continue;

      final escapedLabel = RegExp.escape(label);
      final pattern = RegExp('(?<![a-z0-9])$escapedLabel(?![a-z0-9])');
      final matches = pattern.allMatches(normalized);
      for (final match in matches) {
        candidates.add(
          _BookCandidate(
            label: label,
            canonicalBook: canonicalBook,
            index: match.start,
          ),
        );
      }
    }

    candidates.sort((a, b) => b.index.compareTo(a.index));

    for (final candidate in candidates) {
      final tail = normalized.substring(candidate.index + candidate.label.length);
      final cleaned = tail
          .replaceAll(_noise, ' ')
          .replaceAll(RegExp(r'[^0-9\s]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      final numbers = RegExp(r'\d+').allMatches(cleaned).toList();
      if (numbers.isEmpty) continue;

      if (numbers.length >= 2) {
        final chapter = int.tryParse(numbers[0].group(0)!);
        final verse = int.tryParse(numbers[1].group(0)!);
        if (chapter != null && verse != null && chapter > 0 && verse > 0) {
          return VerseReference(
            book: candidate.canonicalBook,
            chapter: chapter,
            verse: verse,
          );
        }
      }

      final chapter = int.tryParse(numbers[0].group(0)!);
      if (chapter != null && chapter > 0) {
        return VerseReference(
          book: candidate.canonicalBook,
          chapter: chapter,
          verse: 1,
        );
      }
    }

    return null;
  }
}

class _BookCandidate {
  final String label;
  final String canonicalBook;
  final int index;

  const _BookCandidate({
    required this.label,
    required this.canonicalBook,
    required this.index,
  });
}
