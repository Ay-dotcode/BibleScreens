import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// ignore: unused_import
import '../utils/color_compat.dart';

class AppSettings extends ChangeNotifier {
  // Display
  double verseFontSize = 52;
  double refFontSize = 28;
  Color verseColor = Colors.white;
  Color refColor = const Color(0xFFB0BEC5);
  Color bgColor = const Color(0xFF0A0A14);
  String fontFamily = 'Georgia';
  bool showTranslation = true;
  bool showReference = true;

  // Bible
  String translation = 'kjv';

  // Transcription panel
  bool showTranscript = true;
  double transcriptOpacity = 0.7;

  static AppSettings? _instance;
  static AppSettings get instance => _instance ??= AppSettings._();
  AppSettings._();

  File? _file;

  Future<void> load() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _file = File(p.join(dir.path, 'church_display', 'settings.json'));
      if (await _file!.exists()) {
        final json = jsonDecode(await _file!.readAsString());
        verseFontSize = (json['verseFontSize'] ?? verseFontSize).toDouble();
        refFontSize = (json['refFontSize'] ?? refFontSize).toDouble();
        showTranslation = json['showTranslation'] ?? showTranslation;
        showReference = json['showReference'] ?? showReference;
        translation = json['translation'] ?? translation;
        showTranscript = json['showTranscript'] ?? showTranscript;
        transcriptOpacity =
            (json['transcriptOpacity'] ?? transcriptOpacity).toDouble();
        fontFamily = json['fontFamily'] ?? fontFamily;
        if (json['bgColor'] != null) bgColor = Color(json['bgColor']);
        if (json['verseColor'] != null) verseColor = Color(json['verseColor']);
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> save() async {
    try {
      await _file?.writeAsString(jsonEncode({
        'verseFontSize': verseFontSize,
        'refFontSize': refFontSize,
        'showTranslation': showTranslation,
        'showReference': showReference,
        'translation': translation,
        'showTranscript': showTranscript,
        'transcriptOpacity': transcriptOpacity,
        'fontFamily': fontFamily,
        'bgColor': bgColor.toARGB32(),
        'verseColor': verseColor.toARGB32(),
      }));
    } catch (_) {}
  }

  void update(void Function(AppSettings s) fn) {
    fn(this);
    notifyListeners();
    save();
  }
}
