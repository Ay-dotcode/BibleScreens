class Song {
  final int id;
  final String title;
  final String author;
  final String copyright;
  final String administrator;
  final String referenceNumber;

  const Song({
    required this.id,
    required this.title,
    required this.author,
    required this.copyright,
    required this.administrator,
    required this.referenceNumber,
  });

  factory Song.fromMap(Map<String, dynamic> map) {
    return Song(
      id: map['rowid'] as int,
      title: (map['title'] as String? ?? '').trim(),
      author: (map['author'] as String? ?? '').trim(),
      copyright: (map['copyright'] as String? ?? '').trim(),
      administrator: (map['administrator'] as String? ?? '').trim(),
      referenceNumber: (map['reference_number'] as String? ?? '').trim(),
    );
  }

  @override
  String toString() => 'Song($id, $title)';
}

class SongLyrics {
  final int songId;

  /// All slide texts in order, grouped by section.
  /// e.g. [SongSection('Verse 1', ['line1','line2']), ...]
  final List<SongSection> sections;

  const SongLyrics({required this.songId, required this.sections});

  /// Flat list of all slide strings (one per projected slide).
  List<String> get slides =>
      sections.map((s) => s.toSlideText()).toList();
}

class SongSection {
  final String label; // e.g. 'Verse 1', 'Chorus 1', 'Bridge'
  final List<String> lines;

  const SongSection({required this.label, required this.lines});

  String toSlideText() => lines.join('\n');

  @override
  String toString() => '$label\n${lines.join('\n')}';
}