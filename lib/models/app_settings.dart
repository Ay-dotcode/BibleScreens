import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppSettings extends ChangeNotifier {
  static const Color _lightOutputBg = Color(0xFFF3F4F8);
  static const Color _lightOutputVerse = Color(0xFF141722);
  static const Color _lightOutputRef = Color(0xFF4F5C74);
  static const Color _darkOutputBg = Color(0xFF0A0A14);
  static const Color _darkOutputVerse = Colors.white;
  static const Color _darkOutputRef = Color(0xFFB0BEC5);

  // ── Display ────────────────────────────────────────────────────────────────
  double verseFontSize = 52;
  double refFontSize = 28;
  Color verseColor = Colors.white;
  Color refColor = const Color(0xFFB0BEC5);
  Color bgColor = const Color(0xFF0A0A14);
  String fontFamily = 'Georgia';
  bool showTranslation = true;
  bool showReference = true;

  // ── Bible ──────────────────────────────────────────────────────────────────
  String translation = 'kjv';

  // ── Transcript ─────────────────────────────────────────────────────────────
  bool showTranscript = true;
  double transcriptOpacity = 0.7;

  // ── Background image ───────────────────────────────────────────────────────
  /// Original source — URL the user entered, or '' if they picked a local file.
  String outputBackgroundImageUrl = '';

  /// Local cached copy of the background image.  Always prefer this over the
  /// URL on the output screen so a dead link never breaks the display.
  String localBackgroundImagePath = '';

  // ── Output transition ──────────────────────────────────────────────────────
  /// One of: 'crossfade' | 'slideUp' | 'fadeBlack'
  String outputTransition = 'crossfade';

  // ── Theme ──────────────────────────────────────────────────────────────────
  ThemeMode themeMode = ThemeMode.system;

  // ── Singleton ──────────────────────────────────────────────────────────────
  static AppSettings? _instance;
  static AppSettings get instance => _instance ??= AppSettings._();
  AppSettings._();

  File? _file;

  Future<void> load() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _file = File(p.join(dir.path, 'bible_screens', 'settings.json'));
      if (await _file!.exists()) {
        final json =
            jsonDecode(await _file!.readAsString()) as Map<String, dynamic>;

        verseFontSize = (json['verseFontSize'] ?? verseFontSize).toDouble();
        refFontSize = (json['refFontSize'] ?? refFontSize).toDouble();
        showTranslation = json['showTranslation'] ?? showTranslation;
        showReference = json['showReference'] ?? showReference;
        translation = json['translation'] ?? translation;
        showTranscript = json['showTranscript'] ?? showTranscript;
        transcriptOpacity =
            (json['transcriptOpacity'] ?? transcriptOpacity).toDouble();
        fontFamily = json['fontFamily'] ?? fontFamily;
        outputBackgroundImageUrl =
            json['outputBackgroundImageUrl'] ?? outputBackgroundImageUrl;
        localBackgroundImagePath =
            json['localBackgroundImagePath'] ?? localBackgroundImagePath;
        outputTransition = json['outputTransition'] ?? outputTransition;

        if (json['bgColor'] != null) bgColor = Color(json['bgColor'] as int);
        if (json['verseColor'] != null) {
          verseColor = Color(json['verseColor'] as int);
        }
        if (json['refColor'] != null) refColor = Color(json['refColor'] as int);

        final tm = json['themeMode'] as String?;
        themeMode = switch (tm) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        };

        // Validate that the cached local image still exists
        if (localBackgroundImagePath.isNotEmpty) {
          if (!File(localBackgroundImagePath).existsSync()) {
            localBackgroundImagePath = '';
          }
        }
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> save() async {
    try {
      final dir = _file?.parent;
      if (dir != null && !dir.existsSync()) dir.createSync(recursive: true);
      await _file?.writeAsString(jsonEncode({
        'verseFontSize': verseFontSize,
        'refFontSize': refFontSize,
        'showTranslation': showTranslation,
        'showReference': showReference,
        'translation': translation,
        'showTranscript': showTranscript,
        'transcriptOpacity': transcriptOpacity,
        'outputBackgroundImageUrl': outputBackgroundImageUrl,
        'localBackgroundImagePath': localBackgroundImagePath,
        'outputTransition': outputTransition,
        'fontFamily': fontFamily,
        'bgColor': bgColor.toARGB32(),
        'verseColor': verseColor.toARGB32(),
        'refColor': refColor.toARGB32(),
        'themeMode': switch (themeMode) {
          ThemeMode.light => 'light',
          ThemeMode.dark => 'dark',
          ThemeMode.system => 'system',
        },
      }));
    } catch (_) {}
  }

  void update(void Function(AppSettings s) fn) {
    fn(this);
    notifyListeners();
    save();
  }

  void applyThemeMode(
    ThemeMode mode, {
    required Brightness platformBrightness,
    bool syncOutputPalette = true,
  }) {
    themeMode = mode;

    if (syncOutputPalette) {
      final effectiveBrightness = switch (mode) {
        ThemeMode.light => Brightness.light,
        ThemeMode.dark => Brightness.dark,
        ThemeMode.system => platformBrightness,
      };
      _applyOutputPaletteForBrightness(effectiveBrightness);
    }

    notifyListeners();
    save();
  }

  void _applyOutputPaletteForBrightness(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    bgColor = isDark ? _darkOutputBg : _lightOutputBg;
    verseColor = isDark ? _darkOutputVerse : _lightOutputVerse;
    refColor = isDark ? _darkOutputRef : _lightOutputRef;
  }
}
