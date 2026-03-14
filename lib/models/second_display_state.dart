class SecondDisplayState {
  const SecondDisplayState({
    required this.verseText,
    required this.reference,
    required this.translation,
    required this.showReference,
    required this.showTranslation,
    required this.bgColor,
    required this.verseColor,
    required this.refColor,
    required this.verseFontSize,
    required this.refFontSize,
    required this.fontFamily,
    required this.backgroundImageUrl,
    required this.localBackgroundImagePath,
    required this.transitionType,
  });

  final String verseText;
  final String reference;
  final String translation;
  final bool showReference;
  final bool showTranslation;
  final int bgColor;
  final int verseColor;
  final int refColor;
  final double verseFontSize;
  final double refFontSize;
  final String fontFamily;
  // ── Image ──────────────────────────────────────────────────────────────────
  /// Original URL (kept for reference / re-download).
  final String backgroundImageUrl;

  /// Locally cached copy — preferred over the URL on the output screen.
  final String localBackgroundImagePath;
  // ── Presentation ───────────────────────────────────────────────────────────
  /// One of: 'crossfade' | 'slideUp' | 'fadeBlack'
  final String transitionType;

  factory SecondDisplayState.empty({
    required int bgColor,
    required int verseColor,
    required int refColor,
    required double verseFontSize,
    required double refFontSize,
    required String fontFamily,
    required String backgroundImageUrl,
    String localBackgroundImagePath = '',
    String transitionType = 'crossfade',
  }) {
    return SecondDisplayState(
      verseText: '',
      reference: '',
      translation: '',
      showReference: true,
      showTranslation: true,
      bgColor: bgColor,
      verseColor: verseColor,
      refColor: refColor,
      verseFontSize: verseFontSize,
      refFontSize: refFontSize,
      fontFamily: fontFamily,
      backgroundImageUrl: backgroundImageUrl,
      localBackgroundImagePath: localBackgroundImagePath,
      transitionType: transitionType,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'verseText': verseText,
      'reference': reference,
      'translation': translation,
      'showReference': showReference,
      'showTranslation': showTranslation,
      'bgColor': bgColor,
      'verseColor': verseColor,
      'refColor': refColor,
      'verseFontSize': verseFontSize,
      'refFontSize': refFontSize,
      'fontFamily': fontFamily,
      'backgroundImageUrl': backgroundImageUrl,
      'localBackgroundImagePath': localBackgroundImagePath,
      'transitionType': transitionType,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
  }

  factory SecondDisplayState.fromJson(Map<String, dynamic> json) {
    return SecondDisplayState(
      verseText: json['verseText'] ?? '',
      reference: json['reference'] ?? '',
      translation: json['translation'] ?? '',
      showReference: json['showReference'] ?? true,
      showTranslation: json['showTranslation'] ?? true,
      bgColor: json['bgColor'] ?? 0xFF0A0A14,
      verseColor: json['verseColor'] ?? 0xFFFFFFFF,
      refColor: json['refColor'] ?? 0xFFB0BEC5,
      verseFontSize: (json['verseFontSize'] ?? 52.0).toDouble(),
      refFontSize: (json['refFontSize'] ?? 28.0).toDouble(),
      fontFamily: json['fontFamily'] ?? 'Georgia',
      backgroundImageUrl: json['backgroundImageUrl'] ?? '',
      localBackgroundImagePath: json['localBackgroundImagePath'] ?? '',
      transitionType: json['transitionType'] ?? 'crossfade',
    );
  }
}
