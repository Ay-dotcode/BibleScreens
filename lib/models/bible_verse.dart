class VerseReference {
  final String book;
  final int chapter;
  final int verse;

  const VerseReference({
    required this.book,
    required this.chapter,
    required this.verse,
  });

  String get display => '$book $chapter:$verse';

  @override
  bool operator ==(Object other) =>
      other is VerseReference &&
      other.book == book &&
      other.chapter == chapter &&
      other.verse == verse;

  @override
  int get hashCode => Object.hash(book, chapter, verse);
}

class BibleVerse {
  final VerseReference reference;
  final String text;
  final String translation;

  const BibleVerse({
    required this.reference,
    required this.text,
    required this.translation,
  });
}
