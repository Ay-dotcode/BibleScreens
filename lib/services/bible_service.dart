import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/bible_verse.dart';
import '../utils/bible_books.dart';
import '../utils/bible_chapters.dart';

typedef OfflineDownloadProgress = void Function(
  int completedChapters,
  int totalChapters,
  String currentLabel,
);

/// Fetches Bible verse text using the free bible-api.com API (no key needed).
/// Results are cached locally as JSON so they load instantly after first use.
class BibleService {
  static const String _baseUrl = 'https://bible-api.com';
  static const String _defaultTranslation = 'kjv';

  String _translation = _defaultTranslation;
  final Map<String, String> _memCache = {};
  File? _cacheFile;

  String get translation => _translation;
  set translation(String value) {
    _translation = value;
    _memCache.clear(); // clear when translation changes
  }

  /// Available translations on bible-api.com
  static const List<Map<String, String>> availableTranslations = [
    {'id': 'kjv', 'name': 'King James Version'},
    {'id': 'web', 'name': 'World English Bible'},
    {'id': 'asv', 'name': 'American Standard Version'},
    {'id': 'bbe', 'name': 'Bible in Basic English'},
    {'id': 'darby', 'name': 'Darby Bible'},
    {'id': 'dra', 'name': 'Douay-Rheims'},
    {'id': 'ylt', 'name': 'Young\'s Literal Translation'},
  ];

  Future<void> init() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory(p.join(dir.path, 'church_display'));
      if (!await cacheDir.exists()) await cacheDir.create(recursive: true);
      _cacheFile = File(p.join(cacheDir.path, 'verse_cache.json'));
      await _loadDiskCache();
    } catch (_) {
      // Cache is optional — app still works without it
    }
  }

  Future<void> _loadDiskCache() async {
    try {
      if (_cacheFile != null && await _cacheFile!.exists()) {
        final content = await _cacheFile!.readAsString();
        final Map<String, dynamic> json = jsonDecode(content);
        json.forEach((k, v) => _memCache[k] = v as String);
      }
    } catch (_) {}
  }

  Future<void> _saveDiskCache() async {
    try {
      await _cacheFile?.writeAsString(jsonEncode(_memCache));
    } catch (_) {}
  }

  /// Fetches the text for [ref]. Returns a [BibleVerse] or throws on failure.
  Future<BibleVerse> fetchVerse(VerseReference ref) async {
    final cacheKey = '${ref.display}|$_translation';

    // Memory cache hit
    if (_memCache.containsKey(cacheKey)) {
      return BibleVerse(
        reference: ref,
        text: _memCache[cacheKey]!,
        translation: _translation,
      );
    }

    // Build API URL
    final apiBook = BibleBooks.apiPath(ref.book) ??
        ref.book.toLowerCase().replaceAll(' ', '+');
    final url =
        '$_baseUrl/$apiBook+${ref.chapter}:${ref.verse}?translation=$_translation';

    final response =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('API returned ${response.statusCode} for ${ref.display}');
    }

    final data = jsonDecode(response.body);
    final text = (data['text'] as String).trim();

    if (text.isEmpty) {
      throw Exception('No text returned for ${ref.display}');
    }

    _memCache[cacheKey] = text;
    _saveDiskCache(); // fire-and-forget

    return BibleVerse(
      reference: ref,
      text: text,
      translation: _translation.toUpperCase(),
    );
  }

  Future<void> preloadEntireTranslation({
    String? translation,
    OfflineDownloadProgress? onProgress,
  }) async {
    await init();

    if (translation != null) {
      _translation = translation;
    }

    final total = BibleChapters.totalChapters;
    var completed = 0;

    for (final book in BibleBooks.canonicalBooks) {
      final chapterCount = BibleChapters.counts[book] ?? 0;
      if (chapterCount <= 0) continue;

      for (var chapter = 1; chapter <= chapterCount; chapter++) {
        final label = '$book $chapter';
        onProgress?.call(completed, total, label);

        try {
          await _fetchAndCacheChapter(book: book, chapter: chapter);
        } catch (_) {
          // Keep going so one chapter failure doesn't abort full sync.
        }

        completed++;
        if (completed % 15 == 0) {
          await _saveDiskCache();
        }
      }
    }

    await _saveDiskCache();
    onProgress?.call(total, total, 'Done');
  }

  Future<void> _fetchAndCacheChapter({
    required String book,
    required int chapter,
  }) async {
    final metaKey = _chapterMetaKey(book, chapter);
    if (_memCache.containsKey(metaKey)) return;

    final apiBook =
        BibleBooks.apiPath(book) ?? book.toLowerCase().replaceAll(' ', '+');
    final url = '$_baseUrl/$apiBook+$chapter?translation=$_translation';

    final response =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final verses = (data['verses'] as List?) ?? const <dynamic>[];
    if (verses.isEmpty) return;

    for (final verseEntry in verses) {
      if (verseEntry is! Map<String, dynamic>) continue;
      final verse = verseEntry['verse'];
      final verseText = (verseEntry['text'] as String?)?.trim();
      if (verse is! int || verseText == null || verseText.isEmpty) continue;

      final key = '$book $chapter:$verse|$_translation';
      _memCache[key] = verseText;
    }

    _memCache[metaKey] = '1';
  }

  String _chapterMetaKey(String book, int chapter) =>
      '__chapter_cached__$book:$chapter|$_translation';
}
