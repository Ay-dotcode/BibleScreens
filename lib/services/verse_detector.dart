import '../models/bible_verse.dart';
import '../utils/bible_books.dart';
import '../utils/number_words.dart';

// ── Intent types ──────────────────────────────────────────────────────────────

sealed class DetectedIntent {}

class VerseIntent extends DetectedIntent {
  final VerseReference ref;
  VerseIntent(this.ref);
}

class VerseRangeIntent extends DetectedIntent {
  final VerseReference start;
  final int endVerse;
  VerseRangeIntent({required this.start, required this.endVerse});
}

class NavigationIntent extends DetectedIntent {
  final NavigationAction action;
  final int? targetVerse;
  NavigationIntent(this.action, {this.targetVerse});
}

class TranslationIntent extends DetectedIntent {
  final String translationId;
  TranslationIntent(this.translationId);
}

enum NavigationAction { next, specific }

// ── Detector ──────────────────────────────────────────────────────────────────

class VerseDetector {
  static final _noise = RegExp(
    r'\b(chapter|verse|verses|the|of|at|in|from|a|an)\b',
    caseSensitive: false,
  );

  // Translation spoken name → id.
  // Longer phrases listed first so they match before shorter substrings.
  static const Map<String, String> _translationMap = {
    'king james version': 'kjv',
    'king james': 'kjv',
    'world english bible': 'web',
    'world english': 'web',
    'american standard version': 'asv',
    'american standard': 'asv',
    'bible in basic english': 'bbe',
    'basic english': 'bbe',
    'youngs literal translation': 'ylt',
    'youngs literal': 'ylt',
    'authorized king james': 'akjv',
    'revised new king james': 'rnkjv',
    'conservative version': 'acv',
    'kjv': 'kjv',
    'web': 'web',
    'asv': 'asv',
    'bbe': 'bbe',
    'ylt': 'ylt',
    'akjv': 'akjv',
    'acv': 'acv',
    'rnkjv': 'rnkjv',
  };

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Detects the intent from a transcript segment.
  ///
  /// [inVerseMode] enables navigation commands (next, verse N) — only pass
  /// true when a verse is currently live on the display.
  static DetectedIntent? detectIntent(
    String rawText, {
    bool inVerseMode = false,
  }) {
    if (rawText.trim().isEmpty) return null;

    // Translation switch — always active, higher priority than verse detection
    final trans = _detectTranslation(rawText);
    if (trans != null) return trans;

    // Navigation — only when a verse is already showing
    if (inVerseMode) {
      final nav = _detectNavigation(rawText);
      if (nav != null) return nav;
    }

    // Verse range or single verse
    return _detectVerseOrRange(rawText);
  }

  /// Legacy single-verse detect kept for any existing call sites.
  static VerseReference? detect(String rawText) {
    final intent = _detectVerseOrRange(rawText);
    if (intent is VerseIntent) return intent.ref;
    if (intent is VerseRangeIntent) return intent.start;
    return null;
  }

  // ── Translation detection ──────────────────────────────────────────────────

  static TranslationIntent? _detectTranslation(String rawText) {
    final lower = rawText.toLowerCase();
    // Sort by length descending so "king james version" beats "king james"
    final phrases = _translationMap.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final phrase in phrases) {
      final pattern = RegExp(
        '(?<![a-z])${RegExp.escape(phrase)}(?![a-z])',
        caseSensitive: false,
      );
      if (pattern.hasMatch(lower)) {
        return TranslationIntent(_translationMap[phrase]!);
      }
    }
    return null;
  }

  // ── Navigation detection ───────────────────────────────────────────────────

  // Match "next verse", "next one", "next" etc. anchored to end of utterance
  static final _nextRe = RegExp(
    r'\b(next\s+verse|next\s+one|go\s+to\s+next|read\s+next|move\s+on|next)\s*$',
    caseSensitive: false,
  );

  // Match "verse 6" / "vs 6" / "v 6" anchored to end
  static final _specificRe = RegExp(
    r'\b(?:verse|vs\.?|v\.?)\s+(\d+)\s*$',
    caseSensitive: false,
  );

  static NavigationIntent? _detectNavigation(String rawText) {
    final t = rawText.trim();
    if (_nextRe.hasMatch(t)) return NavigationIntent(NavigationAction.next);

    final m = _specificRe.firstMatch(t);
    if (m != null) {
      final v = int.tryParse(m.group(1)!);
      if (v != null && v > 0) {
        return NavigationIntent(NavigationAction.specific, targetVerse: v);
      }
    }
    return null;
  }

  // ── Verse / range detection ────────────────────────────────────────────────

  static DetectedIntent? _detectVerseOrRange(String rawText) {
    if (rawText.trim().isEmpty) return null;

    final rawLower = rawText.toLowerCase();
    final normalized = NumberWords.convert(rawLower);

    final candidates = <_BookCandidate>[];
    for (final label in BibleBooks.sortedKeys) {
      final canonicalBook = BibleBooks.resolve(label);
      if (canonicalBook == null) continue;
      final pattern = RegExp(
        '(?<![a-z0-9])${RegExp.escape(label)}(?![a-z0-9])',
      );
      for (final m in pattern.allMatches(normalized)) {
        candidates.add(_BookCandidate(
          label: label,
          canonicalBook: canonicalBook,
          index: m.start,
        ));
      }
    }
    candidates.sort((a, b) {
      final byIndex = b.index.compareTo(a.index);
      if (byIndex != 0) return byIndex;
      return b.label.length.compareTo(a.label.length);
    });

    for (final c in candidates) {
      final tail = normalized.substring(c.index + c.label.length);
      final rawTail = (c.index + c.label.length <= rawLower.length)
          ? rawLower.substring(c.index + c.label.length)
          : tail;

      // Try range first ("1 2 to 3", "1:2-3")
      final range = _tryParseRange(rawTail, c.canonicalBook);
      if (range != null) return range;

      // Single verse
      final cleaned = tail
          .replaceAll(_noise, ' ')
          .replaceAll(RegExp(r'[^0-9\s]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      final nums = RegExp(r'\d+').allMatches(cleaned).toList();
      if (nums.isEmpty) continue;

      if (nums.length >= 2) {
        final ch = int.tryParse(nums[0].group(0)!);
        final vs = int.tryParse(nums[1].group(0)!);
        if (ch != null && vs != null && ch > 0 && vs > 0) {
          return VerseIntent(
              VerseReference(book: c.canonicalBook, chapter: ch, verse: vs));
        }
      }

      final ch = int.tryParse(nums[0].group(0)!);
      if (ch != null && ch > 0) {
        return VerseIntent(
            VerseReference(book: c.canonicalBook, chapter: ch, verse: 1));
      }
    }
    return null;
  }

  /// Parses a range like "1 2 to 3", "1:2-3", "chapter 1 verse 2 through 3".
  static VerseRangeIntent? _tryParseRange(String tail, String book) {
    final raw = tail.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    final n = NumberWords.convert(tail.toLowerCase());

    // chapter separator startVerse rangeWord endVerse
    final re = RegExp(
      r'(?:chapter\s+)?(\d+)' // chapter
      r'(?:\s*[:\s]\s*)' // : or space
      r'(\d+)' // start verse
      r'\s*(?:to|through|thru|[-–])\s*' // range word
      r'(\d+)', // end verse
      caseSensitive: false,
    );

    final m = re.firstMatch(raw) ?? re.firstMatch(n);
    if (m == null) return null;

    final ch = int.tryParse(m.group(1)!);
    final sv = int.tryParse(m.group(2)!);
    final ev = int.tryParse(m.group(3)!);
    if (ch == null || sv == null || ev == null) return null;
    if (ch <= 0 || sv <= 0 || ev < sv) return null;

    return VerseRangeIntent(
      start: VerseReference(book: book, chapter: ch, verse: sv),
      endVerse: ev,
    );
  }
}

// ── Internal ──────────────────────────────────────────────────────────────────

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
