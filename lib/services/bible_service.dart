import 'package:flutter/services.dart';
import 'package:xml/xml.dart';

import '../models/bible_verse.dart';

/// Fully offline Bible service backed by bundled XML assets.
/// Replaces the old HTTP + verse_cache.json implementation entirely.
/// Same public API as before — nothing else in the app needs to change.
class BibleService {
  static const String _defaultTranslation = 'kjv';

  // ── Translation registry ───────────────────────────────────────────────────
  // Keys are lowercase to match existing AppSettings translation IDs.

  static const Map<String, String> _assetPaths = {
    'kjv': 'assets/bibles/KJV.xml',
    'web': 'assets/bibles/WEB.xml',
    'asv': 'assets/bibles/ASV.xml',
    'bbe': 'assets/bibles/BBE.xml',
    'ylt': 'assets/bibles/YLT.xml',
    'akjv': 'assets/bibles/AKJV.xml',
    'acv': 'assets/bibles/ACV.xml',
    'rnkjv': 'assets/bibles/RNKJV.xml',
  };

  static const List<Map<String, String>> availableTranslations = [
    {'id': 'kjv', 'name': 'King James Version'},
    {'id': 'akjv', 'name': 'Authorized King James Version'},
    {'id': 'rnkjv', 'name': 'Revised New King James Version'},
    {'id': 'web', 'name': 'World English Bible'},
    {'id': 'asv', 'name': 'American Standard Version'},
    {'id': 'acv', 'name': 'A Conservative Version'},
    {'id': 'bbe', 'name': 'Bible in Basic English'},
    {'id': 'ylt', 'name': "Young's Literal Translation"},
  ];

  // ── State ──────────────────────────────────────────────────────────────────

  String _translation = _defaultTranslation;

  String get translation => _translation;
  set translation(String value) {
    _translation = value.toLowerCase();
  }

  // Parsed books per translation, loaded lazily on first access.
  // _cache[translationId][bookName][chapter][verse] = text
  final Map<String, Map<String, Map<int, Map<int, String>>>> _cache = {};

  // ─────────────────────────────────────────────────────────────────────────
  // Public API — identical surface to old BibleService
  // ─────────────────────────────────────────────────────────────────────────

  /// No-op — kept for compatibility with existing init() call sites.
  Future<void> init() async {}

  /// Fetches the text for [ref]. Throws on failure (book/chapter/verse missing).
  Future<BibleVerse> fetchVerse(VerseReference ref) async {
    final books = await _loadTranslation(_translation);

    // Match book name case-insensitively
    final bookKey = _findBookKey(books, ref.book);
    if (bookKey == null) {
      throw Exception('Book not found: ${ref.book}');
    }

    final chapter = books[bookKey]?[ref.chapter];
    if (chapter == null) {
      throw Exception('Chapter not found: ${ref.book} ${ref.chapter}');
    }

    final text = chapter[ref.verse];
    if (text == null || text.isEmpty) {
      throw Exception(
          'Verse not found: ${ref.book} ${ref.chapter}:${ref.verse}');
    }

    return BibleVerse(
      reference: ref,
      text: text,
      translation: _translation.toUpperCase(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Internal — XML loading and parsing
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, Map<int, Map<int, String>>>> _loadTranslation(
      String trans) async {
    final t = _assetPaths.containsKey(trans) ? trans : _defaultTranslation;
    if (_cache.containsKey(t)) return _cache[t]!;

    final path = _assetPaths[t]!;
    final raw = await rootBundle.loadString(path);
    final parsed = _parseXml(raw);
    _cache[t] = parsed;
    return parsed;
  }

  /// Parses the XMLBIBLE format into:
  ///   bookName (lowercase) → chapterNumber → verseNumber → text
  Map<String, Map<int, Map<int, String>>> _parseXml(String xml) {
    final doc = XmlDocument.parse(xml);
    final result = <String, Map<int, Map<int, String>>>{};

    for (final bookEl in doc.findAllElements('BIBLEBOOK')) {
      final bname = (bookEl.getAttribute('bname') ?? '').toLowerCase();
      if (bname.isEmpty) continue;

      final chapters = <int, Map<int, String>>{};

      for (final chEl in bookEl.findElements('CHAPTER')) {
        final cn = int.tryParse(chEl.getAttribute('cnumber') ?? '') ?? 0;
        if (cn == 0) continue;
        final verses = <int, String>{};

        for (final vEl in chEl.findElements('VERS')) {
          final vn = int.tryParse(vEl.getAttribute('vnumber') ?? '') ?? 0;
          if (vn == 0) continue;
          verses[vn] = vEl.innerText.trim();
        }
        chapters[cn] = verses;
      }

      result[bname] = chapters;

      // Also index by short name (e.g. "gen", "ps") for alias lookups
      final bsname = (bookEl.getAttribute('bsname') ?? '').toLowerCase();
      if (bsname.isNotEmpty && bsname != bname) {
        result[bsname] = chapters;
      }
    }

    return result;
  }

  /// Finds the matching book key case-insensitively, also handling common
  /// spoken variants (e.g. "psalms" → "psalm", "1st samuel" → "1 samuel").
  String? _findBookKey(
      Map<String, Map<int, Map<int, String>>> books, String name) {
    final lower = name.toLowerCase().trim();

    // Direct match
    if (books.containsKey(lower)) return lower;

    // Try normalised variants
    for (final variant in _bookVariants(lower)) {
      if (books.containsKey(variant)) return variant;
    }

    // Fuzzy: find any key that starts with the search term
    for (final key in books.keys) {
      if (key.startsWith(lower) || lower.startsWith(key)) return key;
    }

    return null;
  }

  static List<String> _bookVariants(String name) {
    return [
      name.replaceAll('psalms', 'psalm'),
      name.replaceAll('1st ', '1 '),
      name.replaceAll('2nd ', '2 '),
      name.replaceAll('3rd ', '3 '),
      name.replaceAll('first ', '1 '),
      name.replaceAll('second ', '2 '),
      name.replaceAll('third ', '3 '),
      name.replaceAll('song of songs', 'song of solomon'),
      name.replaceAll('song of solomon', 'song of songs'),
      name.replaceAll('revelation', 'rev'),
      name.replaceAll('rev', 'revelation'),
    ];
  }
}
