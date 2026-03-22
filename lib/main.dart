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

  // ── Parse launch flags ─────────────────────────────────────────────────────
  //
  // --display-fullscreen  launched by bridge when a second monitor is detected:
  //                       borderless, always-on-top, positioned to fill that display
  // --display-window      launched by bridge on single-display setups:
  //                       normal titled window
  // --display-window /
  // --display             legacy flag, treated as --display-window

  final isFullscreen = args.contains('--display-fullscreen');
  final isDisplayWindow =
      args.contains('--display-window') || args.contains('--display');
  final isDisplayMode = isFullscreen || isDisplayWindow;

  // Parse optional screen geometry passed by the bridge (fullscreen only)
  final screenX = _intArg(args, '--screen-x');
  final screenY = _intArg(args, '--screen-y');
  final screenW = _intArg(args, '--screen-w');
  final screenH = _intArg(args, '--screen-h');
  final hasGeometry =
      screenX != null && screenY != null && screenW != null && screenH != null;

  await AppSettings.instance.load();

  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    await windowManager.ensureInitialized();

    if (isFullscreen) {
      // ── Borderless fullscreen on second display ──────────────────────────
      final opts = WindowOptions(
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: false,
        alwaysOnTop: true,
        skipTaskbar: false,
        backgroundColor: Colors.transparent,
        // Start at the right position if geometry was provided
        size: hasGeometry ? Size(screenW.toDouble(), screenH.toDouble()) : null,
      );

      await windowManager.waitUntilReadyToShow(opts, () async {
        if (hasGeometry) {
          await windowManager.setBounds(
            Rect.fromLTWH(
              screenX.toDouble(),
              screenY.toDouble(),
              screenW.toDouble(),
              screenH.toDouble(),
            ),
          );
          await windowManager.setFullScreen(true);
        }
        await windowManager.show();
        await windowManager.focus();
      });
    } else if (isDisplayWindow) {
      // ── Normal titled window (single display / no second monitor) ─────────
      const opts = WindowOptions(
        title: 'Church Display — Output',
        titleBarStyle: TitleBarStyle.normal,
        windowButtonVisibility: true,
        alwaysOnTop: false,
        size: Size(960, 600),
        minimumSize: Size(640, 400),
      );

      await windowManager.waitUntilReadyToShow(opts, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    } else {
      // ── Control window (main app) ──────────────────────────────────────────
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

  runApp(BibleScreensApp(forceDisplayMode: isDisplayMode));
}

/// Parses an integer argument of the form `--key=value` from [args].
int? _intArg(List<String> args, String key) {
  for (final arg in args) {
    if (arg.startsWith('$key=')) {
      return int.tryParse(arg.substring(key.length + 1));
    }
  }
  return null;
}
