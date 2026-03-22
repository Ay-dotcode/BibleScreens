const List<String> kBibleGrammar = [
  // ── Old Testament ──────────────────────────────────────────────────────────
  "genesis", "exodus", "leviticus", "numbers", "deuteronomy",
  "joshua", "judges", "ruth",
  "first samuel", "second samuel", "first kings", "second kings",
  "first chronicles", "second chronicles",
  "ezra", "nehemiah", "esther", "job", "psalms", "psalm",
  "proverbs", "ecclesiastes", "song of solomon", "song of songs",
  "isaiah", "jeremiah", "lamentations", "ezekiel", "daniel",
  "hosea", "joel", "amos", "obadiah", "jonah", "micah",
  "nahum", "habakkuk", "zephaniah", "haggai", "zechariah", "malachi",

  // ── New Testament ──────────────────────────────────────────────────────────
  "matthew", "mark", "luke", "john",
  "acts", "romans",
  "first corinthians", "second corinthians",
  "galatians", "ephesians", "philippians", "colossians",
  "first thessalonians", "second thessalonians",
  "first timothy", "second timothy",
  "titus", "philemon", "hebrews", "james",
  "first peter", "second peter",
  "first john", "second john", "third john",
  "jude", "revelation",

  // ── Short spoken aliases ───────────────────────────────────────────────────
  "gen", "ex", "lev", "num", "deut",
  "josh", "judg", "sam", "kings", "chron",
  "neh", "est", "prov", "eccl",
  "isa", "jer", "lam", "ezek", "dan",
  "hos", "mic", "nah", "hab", "zeph", "zech", "mal",
  "matt", "rom", "cor", "gal", "eph", "phil", "col",
  "thess", "tim", "heb", "jas", "pet", "rev",

  // ── Number words 1–150 ────────────────────────────────────────────────────
  "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
  "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen",
  "seventeen", "eighteen", "nineteen", "twenty",
  "twenty one", "twenty two", "twenty three", "twenty four", "twenty five",
  "twenty six", "twenty seven", "twenty eight", "twenty nine", "thirty",
  "thirty one", "thirty two", "thirty three", "thirty four", "thirty five",
  "thirty six", "thirty seven", "thirty eight", "thirty nine", "forty",
  "forty one", "forty two", "forty three", "forty four", "forty five",
  "forty six", "forty seven", "forty eight", "forty nine", "fifty",
  "fifty one", "fifty two", "fifty three", "fifty four", "fifty five",
  "fifty six", "fifty seven", "fifty eight", "fifty nine", "sixty",
  "sixty one", "sixty two", "sixty three", "sixty four", "sixty five",
  "sixty six", "sixty seven", "sixty eight", "sixty nine", "seventy",
  "seventy one", "seventy two", "seventy three", "seventy four", "seventy five",
  "seventy six", "seventy seven", "seventy eight", "seventy nine", "eighty",
  "eighty one", "eighty two", "eighty three", "eighty four", "eighty five",
  "eighty six", "eighty seven", "eighty eight", "eighty nine", "ninety",
  "ninety one", "ninety two", "ninety three", "ninety four", "ninety five",
  "ninety six", "ninety seven", "ninety eight", "ninety nine",
  "one hundred", "one hundred and one", "one hundred and two",
  "one hundred and ten", "one hundred and nineteen", "one hundred and twenty",
  "one hundred and fifty",

  // ── Connective words used in spoken references ────────────────────────────
  "chapter", "verse", "verses", "colon", "through", "to", "and",
  "first", "second", "third",

  // ── Required Vosk unknown token ───────────────────────────────────────────
  "[unk]",
];
