import 'dart:async';
import 'dart:convert';

import 'package:web/web.dart' as web;

import '../models/second_display_state.dart';

class SecondDisplayBridge {
  static const _stateKey = 'bible_screens.second_screen.state';

  final _controller = StreamController<SecondDisplayState>.broadcast();
  Timer? _pollTimer;
  String? _lastRaw;

  void _startPolling() {
    if (_pollTimer != null) return;
    _pollTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final raw = web.window.localStorage.getItem(_stateKey);
      if (raw == null || raw.isEmpty || raw == _lastRaw) return;
      _lastRaw = raw;
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        _controller.add(SecondDisplayState.fromJson(json));
      } catch (_) {}
    });

    _controller.onCancel = _stopPollingIfIdle;
  }

  void _stopPollingIfIdle() {
    if (_controller.hasListener) return;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> openDisplayWindow() async {
    final uri = Uri.base.replace(queryParameters: {
      ...Uri.base.queryParameters,
      'display': '1',
    });
    final popup = web.window.open(uri.toString(), 'bible_screens_output');
    if (popup == null) {
      web.window.location.assign(uri.toString());
      return;
    }
  }

  Future<void> publish(SecondDisplayState state) async {
    final raw = jsonEncode(state.toJson());
    web.window.localStorage.setItem(_stateKey, raw);
    _lastRaw = raw;
  }

  Stream<SecondDisplayState> listen() {
    _startPolling();
    return _controller.stream;
  }

  Future<SecondDisplayState?> readCurrent() async {
    final raw = web.window.localStorage.getItem(_stateKey);
    if (raw == null || raw.isEmpty) return null;
    try {
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
