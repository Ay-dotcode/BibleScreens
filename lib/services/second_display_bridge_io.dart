import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
      // Ignore malformed/partial writes and keep polling.
    } finally {
      _polling = false;
    }
  }

  Future<File> _ensureStateFile() async {
    if (_stateFile != null) return _stateFile!;

    final baseDir = await getApplicationSupportDirectory();
    final appDir = Directory(p.join(baseDir.path, 'bible_screens'));
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }

    _stateFile = File(p.join(appDir.path, _stateFileName));
    return _stateFile!;
  }

  Future<void> openDisplayWindow() async {
    if (!Platform.isLinux && !Platform.isWindows && !Platform.isMacOS) {
      return;
    }

    final executable = Platform.resolvedExecutable;
    final workingDirectory = File(executable).parent.path;

    try {
      if (Platform.isWindows) {
        await Process.start(
          'cmd',
          ['/c', 'start', '', executable, '--display-window'],
          workingDirectory: workingDirectory,
          mode: ProcessStartMode.detached,
        );
      } else {
        await Process.start(
          executable,
          const ['--display-window'],
          workingDirectory: workingDirectory,
          mode: ProcessStartMode.detached,
        );
      }
    } on ProcessException catch (error) {
      throw StateError(
        'Could not open second display window: ${error.message}',
      );
    }
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
