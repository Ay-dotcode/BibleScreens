/// All 66 books of the Bible with their canonical names and recognized aliases.
/// Sorted longest-name-first so matching is greedy and accurate.
class BibleBooks {
  static const List<Map<String, dynamic>> _books = [
    // ── Old Testament ──────────────────────────────────────────────────────
    {'name': 'Genesis',         'api': 'genesis',         'aliases': ['gen', 'ge', 'gn']},
    {'name': 'Exodus',          'api': 'exodus',          'aliases': ['ex', 'exo', 'exod']},
    {'name': 'Leviticus',       'api': 'leviticus',       'aliases': ['lev', 'le', 'lv']},
    {'name': 'Numbers',         'api': 'numbers',         'aliases': ['num', 'nu', 'nm', 'nb']},
    {'name': 'Deuteronomy',     'api': 'deuteronomy',     'aliases': ['deut', 'dt', 'de']},
    {'name': 'Joshua',          'api': 'joshua',          'aliases': ['josh', 'jos', 'jsh']},
    {'name': 'Judges',          'api': 'judges',          'aliases': ['judg', 'jdg', 'jg', 'jdgs']},
    {'name': 'Ruth',            'api': 'ruth',            'aliases': ['rth', 'ru']},
    {'name': '1 Samuel',        'api': '1+samuel',        'aliases': ['1sam', '1sa', '1s', '1sm']},
    {'name': '2 Samuel',        'api': '2+samuel',        'aliases': ['2sam', '2sa', '2s', '2sm']},
    {'name': '1 Kings',         'api': '1+kings',         'aliases': ['1kgs', '1ki', '1k']},
    {'name': '2 Kings',         'api': '2+kings',         'aliases': ['2kgs', '2ki', '2k']},
    {'name': '1 Chronicles',    'api': '1+chronicles',    'aliases': ['1chr', '1ch', '1chron']},
    {'name': '2 Chronicles',    'api': '2+chronicles',    'aliases': ['2chr', '2ch', '2chron']},
    {'name': 'Ezra',            'api': 'ezra',            'aliases': ['ezr']},
    {'name': 'Nehemiah',        'api': 'nehemiah',        'aliases': ['neh', 'ne']},
    {'name': 'Esther',          'api': 'esther',          'aliases': ['est', 'esth']},
    {'name': 'Job',             'api': 'job',             'aliases': ['jb']},
    {'name': 'Psalms',          'api': 'psalms',          'aliases': ['ps', 'psa', 'psm', 'pss', 'psalm']},
    {'name': 'Proverbs',        'api': 'proverbs',        'aliases': ['prov', 'pro', 'prv', 'pr']},
    {'name': 'Ecclesiastes',    'api': 'ecclesiastes',    'aliases': ['eccles', 'eccl', 'ecc', 'qoh']},
    {'name': 'Song of Solomon', 'api': 'song+of+solomon', 'aliases': ['song', 'sos', 'ss', 'sg', 'song of songs', 'songs']},
    {'name': 'Isaiah',          'api': 'isaiah',          'aliases': ['isa', 'is']},
    {'name': 'Jeremiah',        'api': 'jeremiah',        'aliases': ['jer', 'je', 'jr']},
    {'name': 'Lamentations',    'api': 'lamentations',    'aliases': ['lam', 'la']},
    {'name': 'Ezekiel',         'api': 'ezekiel',         'aliases': ['ezek', 'eze', 'ezk']},
    {'name': 'Daniel',          'api': 'daniel',          'aliases': ['dan', 'da', 'dn']},
    {'name': 'Hosea',           'api': 'hosea',           'aliases': ['hos', 'ho']},
    {'name': 'Joel',            'api': 'joel',            'aliases': ['joe', 'jl']},
    {'name': 'Amos',            'api': 'amos',            'aliases': ['am']},
    {'name': 'Obadiah',         'api': 'obadiah',         'aliases': ['obad', 'ob']},
    {'name': 'Jonah',           'api': 'jonah',           'aliases': ['jon', 'jnh']},
    {'name': 'Micah',           'api': 'micah',           'aliases': ['mic', 'mc']},
    {'name': 'Nahum',           'api': 'nahum',           'aliases': ['nah', 'na']},
    {'name': 'Habakkuk',        'api': 'habakkuk',        'aliases': ['hab', 'hb']},
    {'name': 'Zephaniah',       'api': 'zephaniah',       'aliases': ['zeph', 'zep', 'zp']},
    {'name': 'Haggai',          'api': 'haggai',          'aliases': ['hag', 'hg']},
    {'name': 'Zechariah',       'api': 'zechariah',       'aliases': ['zech', 'zec', 'zc']},
    {'name': 'Malachi',         'api': 'malachi',         'aliases': ['mal', 'ml']},
    // ── New Testament ──────────────────────────────────────────────────────
    {'name': 'Matthew',         'api': 'matthew',         'aliases': ['matt', 'mt']},
    {'name': 'Mark',            'api': 'mark',            'aliases': ['mrk', 'mk', 'mr']},
    {'name': 'Luke',            'api': 'luke',            'aliases': ['luk', 'lk']},
    {'name': 'John',            'api': 'john',            'aliases': ['jhn', 'jn', 'jo']},
    {'name': 'Acts',            'api': 'acts',            'aliases': ['act', 'ac']},
    {'name': 'Romans',          'api': 'romans',          'aliases': ['rom', 'ro', 'rm']},
    {'name': '1 Corinthians',   'api': '1+corinthians',   'aliases': ['1cor', '1co', '1c']},
    {'name': '2 Corinthians',   'api': '2+corinthians',   'aliases': ['2cor', '2co', '2c']},
    {'name': 'Galatians',       'api': 'galatians',       'aliases': ['gal', 'ga']},
    {'name': 'Ephesians',       'api': 'ephesians',       'aliases': ['eph', 'ep']},
    {'name': 'Philippians',     'api': 'philippians',     'aliases': ['phil', 'php', 'pp']},
    {'name': 'Colossians',      'api': 'colossians',      'aliases': ['col']},
    {'name': '1 Thessalonians', 'api': '1+thessalonians', 'aliases': ['1thess', '1th', '1the']},
    {'name': '2 Thessalonians', 'api': '2+thessalonians', 'aliases': ['2thess', '2th', '2the']},
    {'name': '1 Timothy',       'api': '1+timothy',       'aliases': ['1tim', '1ti', '1tm']},
    {'name': '2 Timothy',       'api': '2+timothy',       'aliases': ['2tim', '2ti', '2tm']},
    {'name': 'Titus',           'api': 'titus',           'aliases': ['tit', 'ti']},
    {'name': 'Philemon',        'api': 'philemon',        'aliases': ['phm', 'pm']},
    {'name': 'Hebrews',         'api': 'hebrews',         'aliases': ['heb']},
    {'name': 'James',           'api': 'james',           'aliases': ['jas', 'jm']},
    {'name': '1 Peter',         'api': '1+peter',         'aliases': ['1pet', '1pe', '1pt', '1p']},
    {'name': '2 Peter',         'api': '2+peter',         'aliases': ['2pet', '2pe', '2pt', '2p']},
    {'name': '1 John',          'api': '1+john',          'aliases': ['1jhn', '1jn', '1jo', '1j']},
    {'name': '2 John',          'api': '2+john',          'aliases': ['2jhn', '2jn', '2jo', '2j']},
    {'name': '3 John',          'api': '3+john',          'aliases': ['3jhn', '3jn', '3jo', '3j']},
    {'name': 'Jude',            'api': 'jude',            'aliases': ['jud', 'jd']},
    {'name': 'Revelation',      'api': 'revelation',      'aliases': ['rev', 're', 'rv', 'revelations']},
  ];

  /// Returns every known name / abbreviation → canonical book name.
  static final Map<String, String> _lookup = _buildLookup();

  /// Returns every known API path for a canonical book name.
  static final Map<String, String> _apiPaths = _buildApiPaths();

  static Map<String, String> _buildLookup() {
    final map = <String, String>{};
    for (final book in _books) {
      final name = (book['name'] as String).toLowerCase();
      map[name] = book['name'] as String;
      for (final alias in book['aliases'] as List<String>) {
        map[alias.toLowerCase()] = book['name'] as String;
      }
    }
    return map;
  }

  static Map<String, String> _buildApiPaths() {
    final map = <String, String>{};
    for (final book in _books) {
      map[book['name'] as String] = book['api'] as String;
    }
    return map;
  }

  /// All known labels sorted longest-first (prevents "jo" matching before "john").
  static final List<String> _sortedKeys = (() {
    final keys = _lookup.keys.toList();
    keys.sort((a, b) => b.length.compareTo(a.length));
    return keys;
  })();

  /// Resolves any alias/abbreviation to the canonical book name, or null.
  static String? resolve(String token) => _lookup[token.toLowerCase()];

  /// Returns the bible-api.com path segment for a canonical book name.
  static String? apiPath(String canonicalName) => _apiPaths[canonicalName];

  /// Sorted list of all recognized labels (longest first) for scanning text.
  static List<String> get sortedKeys => _sortedKeys;
}
