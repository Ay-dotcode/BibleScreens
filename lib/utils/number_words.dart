/// Converts English number words into digits within a string.
/// Handles: "three" → "3", "twenty two" → "22", "first" → "1"
/// Also handles ordinals for book prefixes: "first corinthians" → "1 corinthians"
class NumberWords {
  static const Map<String, int> _ones = {
    'zero': 0,
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
    'eleven': 11,
    'twelve': 12,
    'thirteen': 13,
    'fourteen': 14,
    'fifteen': 15,
    'sixteen': 16,
    'seventeen': 17,
    'eighteen': 18,
    'nineteen': 19,
    // Ordinals
    'first': 1,
    'second': 2,
    'third': 3,
    'fourth': 4,
    'fifth': 5,
    'sixth': 6,
    'seventh': 7,
    'eighth': 8,
    'ninth': 9,
    'tenth': 10,
    'eleventh': 11,
    'twelfth': 12,
  };

  static const Map<String, int> _tens = {
    'twenty': 20,
    'thirty': 30,
    'forty': 40,
    'fifty': 50,
    'sixty': 60,
    'seventy': 70,
    'eighty': 80,
    'ninety': 90,
  };

  /// Converts a sentence with word numbers to a version with digit numbers.
  /// Example: "john three sixteen" → "john 3 16"
  /// Example: "first corinthians thirteen four" → "1 corinthians 13 4"
  static String convert(String input) {
    final normalized = input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9:\s\-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Split on whitespace and hyphens (handles "twenty-two")
    final tokens = normalized.split(RegExp(r'[\s\-]+'));
    final output = <String>[];
    int i = 0;

    while (i < tokens.length) {
      final word = tokens[i];

      if (word.isEmpty || word == 'and') {
        i++;
        continue;
      }

      // Tens word followed by ones word → compound number ("twenty two" → 22)
      if (_tens.containsKey(word) &&
          i + 1 < tokens.length &&
          _ones.containsKey(tokens[i + 1])) {
        output.add((_tens[word]! + _ones[tokens[i + 1]]!).toString());
        i += 2;
        continue;
      }

      if (_tens.containsKey(word)) {
        output.add(_tens[word].toString());
        i++;
        continue;
      }

      if (_ones.containsKey(word)) {
        output.add(_ones[word].toString());
        i++;
        continue;
      }

      output.add(word);
      i++;
    }

    return output.join(' ');
  }
}
