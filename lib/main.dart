import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'models/app_settings.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final forceDisplayMode =
      args.contains('--display-window') || args.contains('--display');

  await AppSettings.instance.load();

  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    await windowManager.ensureInitialized();

    if (forceDisplayMode) {
      const opts = WindowOptions(
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: false,
        alwaysOnTop: true,
        skipTaskbar: false,
        backgroundColor: Colors.transparent,
      );
      await windowManager.waitUntilReadyToShow(opts, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    } else {
      const opts = WindowOptions(
        title: 'Church Display — Control',
        titleBarStyle: TitleBarStyle.normal,
        minimumSize: Size(960, 600),
      );
      await windowManager.waitUntilReadyToShow(opts, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    }
  }

  runApp(BibleScreensApp(forceDisplayMode: forceDisplayMode));
}
