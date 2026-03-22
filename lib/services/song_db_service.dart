import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/song.dart';
import '../utils/rtf_parser.dart';
import 'app_storage_service.dart';

/// Service for reading song data from the song database SQLite files.
///
/// On first launch the .db asset files are copied to the app's documents
/// directory so sqflite can open them read-only.
class SongDbService {
  static const _songsAsset = 'assets/databases/Songs.db';
  static const _wordsAsset = 'assets/databases/SongWords.db';
  static const _historyAsset = 'assets/databases/SongHistory.db';

  Database? _songsDb;
  Database? _wordsDb;
  Database? _historyDb;

  bool _initialized = false;

  // ── Initialization ──────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;
    _songsDb = await _openAssetDb(_songsAsset, 'Songs.db');
    _wordsDb = await _openAssetDb(_wordsAsset, 'SongWords.db');
    _historyDb = await _openAssetDb(_historyAsset, 'SongHistory.db');
    _initialized = true;
  }

  Future<void> dispose() async {
    await _songsDb?.close();
    await _wordsDb?.close();
    await _historyDb?.close();
    _initialized = false;
  }

  /// Copy the asset DB to documents dir (if not already there) and open it.
  Future<Database> _openAssetDb(String assetPath, String fileName) async {
    final dir = await AppStorageService.songDatabaseDirectory();
    final dbPath = p.join(dir.path, fileName);

    final file = File(dbPath);
    if (!file.existsSync()) {
      await file.parent.create(recursive: true);
      final data = await rootBundle.load(assetPath);
      final bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await file.writeAsBytes(bytes, flush: true);
    }

    return openDatabase(dbPath, readOnly: true);
  }

  // ── Song Queries ─────────────────────────────────────────────────────────────

  /// Returns all songs sorted by title.
  Future<List<Song>> getAllSongs() async {
    await init();
    final rows = await _songsDb!.query(
      'song',
      columns: [
        'rowid',
        'title',
        'author',
        'copyright',
        'administrator',
        'reference_number'
      ],
      orderBy: 'title COLLATE BINARY ASC',
    );
    return rows.map(Song.fromMap).toList();
  }

  /// Search songs by title or author (case-insensitive).
  Future<List<Song>> searchSongs(String query) async {
    await init();
    if (query.trim().isEmpty) return getAllSongs();

    final q = '%${query.trim()}%';
    final rows = await _songsDb!.query(
      'song',
      columns: [
        'rowid',
        'title',
        'author',
        'copyright',
        'administrator',
        'reference_number'
      ],
      where: 'title COLLATE NOCASE LIKE ? OR author COLLATE NOCASE LIKE ?',
      whereArgs: [q, q],
      orderBy: 'title COLLATE BINARY ASC',
    );
    return rows.map(Song.fromMap).toList();
  }

  /// Get a single [Song] by its rowid.
  Future<Song?> getSongById(int id) async {
    await init();
    final rows = await _songsDb!.query(
      'song',
      columns: [
        'rowid',
        'title',
        'author',
        'copyright',
        'administrator',
        'reference_number'
      ],
      where: 'rowid = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Song.fromMap(rows.first);
  }

  // ── Lyrics ────────────────────────────────────────────────────────────────────

  /// Returns parsed [SongLyrics] for the given song id.
  ///
  /// Returns null if the lyrics row doesn't exist.
  Future<SongLyrics?> getLyrics(int songId) async {
    await init();
    final rows = await _wordsDb!.query(
      'word',
      columns: ['song_id', 'words'],
      where: 'song_id = ?',
      whereArgs: [songId],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final rtf = rows.first['words'] as String? ?? '';
    if (rtf.isEmpty) return null;

    return RtfParser.parse(songId, rtf);
  }

  /// Returns all lyrics as plain text (unsectioned) for a song.
  Future<String?> getLyricsPlainText(int songId) async {
    final lyrics = await getLyrics(songId);
    if (lyrics == null) return null;
    return lyrics.sections
        .map((s) => '${s.label}\n${s.toSlideText()}')
        .join('\n\n');
  }

  // ── History ───────────────────────────────────────────────────────────────────

  /// Returns recently used songs from [SongHistory.db].
  ///
  /// [limit] defaults to 20.
  Future<List<Song>> getRecentSongs({int limit = 20}) async {
    await init();

    // Get distinct song_uids ordered by most recent date
    final historyRows = await _historyDb!.rawQuery('''
      SELECT s.song_uid, s.title, s.author, s.copyright, s.administrator, s.reference_number,
             MAX(a.date) AS last_used
      FROM song s
      JOIN action a ON a.song_id = s.rowid
      GROUP BY s.song_uid
      ORDER BY last_used DESC
      LIMIT ?
    ''', [limit]);

    if (historyRows.isEmpty) return [];

    // Match up with main Songs.db using title (uid may differ across DBs)
    final titles = historyRows.map((r) => r['title'] as String).toList();
    final placeholders = List.filled(titles.length, '?').join(', ');
    final songRows = await _songsDb!.rawQuery(
      'SELECT rowid, title, author, copyright, administrator, reference_number '
      'FROM song WHERE title COLLATE BINARY IN ($placeholders)',
      titles,
    );

    // Build map for ordering
    final songMap = {
      for (final r in songRows) r['title'] as String: Song.fromMap(r)
    };
    final result = <Song>[];
    for (final h in historyRows) {
      final song = songMap[h['title'] as String];
      if (song != null) result.add(song);
    }
    return result;
  }

  // ── Slide helpers ─────────────────────────────────────────────────────────────

  /// Splits a song's lyrics into projection-ready slide strings.
  ///
  /// Each section becomes one slide. Returns an empty list if lyrics not found.
  Future<List<String>> getSongSlides(int songId) async {
    final lyrics = await getLyrics(songId);
    return lyrics?.slides ?? [];
  }
}
