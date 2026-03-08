import 'dart:async';

import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum ListeningState { idle, initializing, listening, paused, error }

class SpeechService {
  final SpeechToText _stt = SpeechToText();
  static const Duration _listenWindow = Duration(minutes: 30);
  static const Duration _pauseWindow = Duration(minutes: 30);

  ListeningState _state = ListeningState.idle;
  ListeningState get state => _state;

  bool _wantListening = false; // user intent
  bool _available = false;
  bool _startingListen = false;
  Timer? _restartTimer;
  DateTime _lastListenAttempt = DateTime.fromMillisecondsSinceEpoch(0);

  final _transcriptController = StreamController<String>.broadcast();
  final _stateController = StreamController<ListeningState>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  static const int _maxTranscriptChars = 500;

  /// Live partial + final transcription text.
  Stream<String> get transcriptStream => _transcriptController.stream;

  /// Listening state changes.
  Stream<ListeningState> get stateStream => _stateController.stream;

  /// Error messages.
  Stream<String> get errorStream => _errorController.stream;

  String _lastTranscript = '';
  String get lastTranscript => _lastTranscript;
  String _stableTranscript = '';
  String _liveTranscript = '';

  Future<bool> init() async {
    _setState(ListeningState.initializing);
    try {
      _available = await _stt.initialize(
        onError: _onError,
        onStatus: _onStatus,
      );
    } on MissingPluginException {
      _available = false;
      _errorController.add(
        'Speech recognition plugin is not available on this platform. '
        'Try Android, iOS, web, or a supported desktop target.',
      );
    } on PlatformException catch (error) {
      _available = false;
      _errorController.add(
          'Speech recognition init failed: ${error.message ?? error.code}');
    } catch (_) {
      _available = false;
      _errorController.add('Speech recognition failed to initialize.');
    }

    if (!_available) {
      _setState(ListeningState.error);
      _errorController.add('Speech recognition not available on this device.');
    } else {
      _setState(ListeningState.idle);
    }
    return _available;
  }

  Future<void> startListening() async {
    if (!_available) return;
    _wantListening = true;
    _stableTranscript = '';
    _liveTranscript = '';
    _lastTranscript = '';
    await _listen();
  }

  Future<void> stopListening() async {
    _wantListening = false;
    _restartTimer?.cancel();
    _restartTimer = null;
    if (_available) {
      await _stt.stop();
    }
    _setState(ListeningState.idle);
  }

  Future<void> _listen() async {
    if (!_wantListening || _stt.isListening || _startingListen) return;

    final now = DateTime.now();
    if (now.difference(_lastListenAttempt) <
        const Duration(milliseconds: 400)) {
      _scheduleRestart(const Duration(milliseconds: 400));
      return;
    }
    _lastListenAttempt = now;
    _startingListen = true;

    _setState(ListeningState.listening);

    try {
      await _stt.listen(
        onResult: _onResult,
        listenFor: _listenWindow,
        pauseFor: _pauseWindow,
        localeId: 'en_US',
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
        ),
      );
    } on MissingPluginException {
      _available = false;
      _wantListening = false;
      _setState(ListeningState.error);
      _errorController.add(
        'Speech recognition plugin is unavailable on this platform.',
      );
    } on PlatformException catch (error) {
      _wantListening = false;
      _setState(ListeningState.error);
      _errorController
          .add('Could not start listening: ${error.message ?? error.code}');
    } catch (error) {
      final message = error.toString().toLowerCase();
      if (message.contains('already started')) {
        _scheduleRestart(const Duration(milliseconds: 700));
      } else {
        _errorController.add('Could not start listening: $error');
      }
    } finally {
      _startingListen = false;
    }
  }

  void _onResult(SpeechRecognitionResult result) {
    final text = result.recognizedWords.trim();
    if (text.isEmpty) return;

    if (result.finalResult) {
      _stableTranscript = _mergeTranscript(_stableTranscript, text);
      _liveTranscript = '';
      _emitTranscript(_stableTranscript);
      return;
    }

    _liveTranscript = text;
    _emitTranscript(_mergeTranscript(_stableTranscript, _liveTranscript));
  }

  void _onStatus(String status) {
    // Keep stream effectively continuous if engine ends unexpectedly.
    if ((status == 'done' || status == 'notListening') && _wantListening) {
      _scheduleRestart(const Duration(milliseconds: 120));
    }
    if (status == 'listening') {
      _setState(ListeningState.listening);
    }
  }

  void _onError(SpeechRecognitionError error) {
    // Transient errors (e.g. "no speech") → just restart
    final transient = {'no-speech', 'audio', 'network', 'aborted'};
    if (transient.contains(error.errorMsg) && _wantListening) {
      _scheduleRestart(const Duration(seconds: 1));
    } else {
      _errorController.add('Recognition error: ${error.errorMsg}');
    }
  }

  void _scheduleRestart(Duration delay) {
    if (!_wantListening || !_available) return;
    _restartTimer?.cancel();
    _restartTimer = Timer(delay, _listen);
  }

  void _setState(ListeningState s) {
    _state = s;
    _stateController.add(s);
  }

  void _emitTranscript(String text) {
    final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.isEmpty) return;

    final clipped = compact.length <= _maxTranscriptChars
        ? compact
        : compact.substring(compact.length - _maxTranscriptChars);

    _lastTranscript = clipped;
    _transcriptController.add(clipped);
  }

  String _mergeTranscript(String base, String incoming) {
    final left = base.trim();
    final right = incoming.trim();
    if (left.isEmpty) return right;
    if (right.isEmpty) return left;

    final leftWords = left.split(RegExp(r'\s+'));
    final rightWords = right.split(RegExp(r'\s+'));
    final maxOverlap = leftWords.length < rightWords.length
        ? leftWords.length
        : rightWords.length;

    for (var overlap = maxOverlap; overlap > 0; overlap--) {
      final leftSlice = leftWords.sublist(leftWords.length - overlap).join(' ');
      final rightSlice = rightWords.sublist(0, overlap).join(' ');
      if (leftSlice == rightSlice) {
        return '${leftWords.join(' ')} ${rightWords.sublist(overlap).join(' ')}'
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
      }
    }

    return '$left $right';
  }

  void dispose() {
    _restartTimer?.cancel();
    _stt.stop();
    _transcriptController.close();
    _stateController.close();
    _errorController.close();
  }
}
