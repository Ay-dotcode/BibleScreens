import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' show Offset;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:screen_retriever/screen_retriever.dart';

import '../models/second_display_state.dart';

class SecondDisplayBridge {
  static const _stateFileName = 'second_display_state.json';

  final _controller = StreamController<SecondDisplayState>.broadcast();
  Timer? _pollTimer;
  String? _lastRaw;
  File? _stateFile;
  bool _polling = false;

  void _startPolling() {
    if (_pollTimer != null) return;
    _pollTimer = Timer.periodic(const Duration(milliseconds: 250), (_) async {
      await _poll();
    });
    _controller.onCancel = _stopPollingIfIdle;
  }

  void _stopPollingIfIdle() {
    if (_controller.hasListener) return;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _poll() async {
    if (_polling) return;
    _polling = true;
    try {
      final file = await _ensureStateFile();
      if (!await file.exists()) return;
      final raw = await file.readAsString();
      if (raw.isEmpty || raw == _lastRaw) return;
      _lastRaw = raw;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _controller.add(SecondDisplayState.fromJson(json));
    } catch (_) {
    } finally {
      _polling = false;
    }
  }

  Future<File> _ensureStateFile() async {
    if (_stateFile != null) return _stateFile!;
    final baseDir = await getApplicationSupportDirectory();
    final appDir = Directory(p.join(baseDir.path, 'bible_screens'));
    if (!await appDir.exists()) await appDir.create(recursive: true);
    _stateFile = File(p.join(appDir.path, _stateFileName));
    return _stateFile!;
  }

  /// Opens the output display window.
  ///
  /// If a second monitor is detected the window launches borderless and
  /// full-screen on that display. Otherwise it opens as a normal titled
  /// window on the primary display.
  Future<void> openDisplayWindow() async {
    if (!Platform.isLinux && !Platform.isWindows && !Platform.isMacOS) return;

    final executable = await _resolveCurrentExecutable();
    final workingDirectory = File(executable).parent.path;

    // Detect displays
    final displays = await screenRetriever.getAllDisplays();
    final hasSecond = displays.length > 1;

    List<String> args;

    if (hasSecond) {
      // Find the first non-primary display
      final primary = await screenRetriever.getPrimaryDisplay();
      final second = displays.firstWhere(
        (d) => d.id != primary.id,
        orElse: () => displays.last,
      );

      final pos = second.visiblePosition ?? const Offset(0, 0);
      final size = second.visibleSize ?? second.size;
      // Pass display bounds so the spawned window can position itself exactly
      args = [
        '--display-fullscreen',
        '--screen-x=${pos.dx.toInt()}',
        '--screen-y=${pos.dy.toInt()}',
        '--screen-w=${size.width.toInt()}',
        '--screen-h=${size.height.toInt()}',
      ];
    } else {
      args = ['--display-window'];
    }

    try {
      if (Platform.isWindows) {
        await Process.start(
          'cmd',
          ['/c', 'start', '', executable, ...args],
          workingDirectory: workingDirectory,
          mode: ProcessStartMode.detached,
        );
      } else {
        await Process.start(
          executable,
          args,
          workingDirectory: workingDirectory,
          environment: Platform.environment,
          mode: ProcessStartMode.detached,
        );
      }
    } on ProcessException catch (error) {
      throw StateError('Could not open display window: ${error.message}');
    }
  }

  Future<String> _resolveCurrentExecutable() async {
    if (Platform.isLinux) {
      final selfExe = File('/proc/self/exe');
      if (await selfExe.exists()) {
        try {
          return await selfExe.resolveSymbolicLinks();
        } catch (_) {}
      }
    }
    return Platform.resolvedExecutable;
  }

  Future<void> publish(SecondDisplayState state) async {
    final file = await _ensureStateFile();
    final raw = jsonEncode(state.toJson());
    await file.writeAsString(raw, flush: true);
    _lastRaw = raw;
  }

  Stream<SecondDisplayState> listen() {
    _startPolling();
    return _controller.stream;
  }

  Future<SecondDisplayState?> readCurrent() async {
    try {
      final file = await _ensureStateFile();
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      if (raw.isEmpty) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return SecondDisplayState.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _controller.close();
  }
}
