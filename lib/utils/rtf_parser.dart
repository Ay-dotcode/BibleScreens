import '../models/song.dart';

/// Parses the EasyWorship RTF lyrics format into [SongLyrics].
///
/// The RTF stores one block of text per song. Sections are indicated by lines
/// like "Verse 1", "Chorus 1", "Bridge", etc.
class RtfParser {
  static const _sectionPattern =
      r'^(Verse|Chorus|Bridge|Pre-Chorus|Intro|Outro|Tag|Ending)\s*\d*$';
  static final _sectionRe = RegExp(_sectionPattern, caseSensitive: false);

  /// Extract plain-text lines from EasyWorship RTF.
  ///
  /// Handles both old-style (`\\fntnamaut text\\par`) and
  /// new-style (`\\sdeasyworship2` format).
  static List<String> extractLines(String rtf) {
    final lines = <String>[];

    // EasyWorship 2 format: text is between last } and \par in pard blocks
    final ew2Pattern = RegExp(r'\}([^\\\r\n{}]+?)\\par');
    // EasyWorship legacy format
    final legacyPattern = RegExp(
      r'\\plain[^}\\]*(?:\\fntnamaut\s*|\\f\d+\s*)([^\\\r\n]+?)\\par',
    );

    bool isEw2 = rtf.contains('sdeasyworship2');

    if (isEw2) {
      for (final m in ew2Pattern.allMatches(rtf)) {
        final text = _cleanRtfText(m.group(1) ?? '');
        if (text.isNotEmpty) lines.add(text);
      }
    } else {
      for (final m in legacyPattern.allMatches(rtf)) {
        final text = _cleanRtfText(m.group(1) ?? '');
        if (text.isNotEmpty) lines.add(text);
      }
    }

    // Fallback: strip all RTF control words and extract remaining text
    if (lines.isEmpty) {
      final stripped = _stripRtf(rtf);
      lines.addAll(
        stripped.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty),
      );
    }

    return lines;
  }

  /// Parse RTF into structured [SongLyrics] with sections.
  static SongLyrics parse(int songId, String rtf) {
    final lines = extractLines(rtf);
    final sections = _groupIntoSections(lines);
    return SongLyrics(songId: songId, sections: sections);
  }

  static List<SongSection> _groupIntoSections(List<String> lines) {
    final sections = <SongSection>[];
    String currentLabel = 'Verse 1';
    final currentLines = <String>[];

    for (final line in lines) {
      if (_sectionRe.hasMatch(line.trim())) {
        // Save current section if it has content
        if (currentLines.isNotEmpty) {
          sections.add(
            SongSection(
              label: currentLabel,
              lines: List.unmodifiable(currentLines),
            ),
          );
          currentLines.clear();
        }
        currentLabel = line.trim();
      } else if (line.trim().isNotEmpty) {
        currentLines.add(line.trim());
      }
    }

    // Save last section
    if (currentLines.isNotEmpty) {
      sections.add(
        SongSection(
          label: currentLabel,
          lines: List.unmodifiable(currentLines),
        ),
      );
    }

    return sections;
  }

  static String _cleanRtfText(String text) {
    return text
        .replaceAll(r"\'92", "'")
        .replaceAll(r"\'91", "'")
        .replaceAll(r"\'93", '"')
        .replaceAll(r"\'94", '"')
        .replaceAll(r"\'96", '–')
        .replaceAll(r"\'97", '—')
        .replaceAll(r"\'e9", 'é')
        .replaceAll(r"\'e8", 'è')
        .replaceAll(r"\'e0", 'à')
        .replaceAll(RegExp(r"\\'[0-9a-fA-F]{2}"), '')
        .replaceAll(RegExp(r'\\[a-zA-Z]+\d*\s?'), '')
        .replaceAll('{', '')
        .replaceAll('}', '')
        .trim();
  }

  /// Brute-force RTF stripper for fallback.
  static String _stripRtf(String rtf) {
    // Remove RTF header
    var text = rtf;
    // Remove groups
    text = text.replaceAll(RegExp(r'\{[^{}]*\}'), '');
    // Remove control words
    text = text.replaceAll(RegExp(r'\\[a-zA-Z]+\-?\d*\s?'), ' ');
    // Remove remaining braces
    text = text.replaceAll(RegExp(r'[{}]'), '');
    // Normalize whitespace
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    return text.trim();
  }
}
