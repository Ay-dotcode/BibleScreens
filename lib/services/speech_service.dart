import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum ListeningState { idle, initializing, listening, paused, error }

class SpeechService {
  final SpeechToText _stt = SpeechToText();

  ListeningState _state = ListeningState.idle;
  ListeningState get state => _state;

  bool _wantListening = false; // user intent
  bool _available = false;

  final _transcriptController = StreamController<String>.broadcast();
  final _stateController = StreamController<ListeningState>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  /// Live partial + final transcription text.
  Stream<String> get transcriptStream => _transcriptController.stream;

  /// Listening state changes.
  Stream<ListeningState> get stateStream => _stateController.stream;

  /// Error messages.
  Stream<String> get errorStream => _errorController.stream;

  String _lastTranscript = '';
  String get lastTranscript => _lastTranscript;

  Future<bool> init() async {
    _setState(ListeningState.initializing);
    _available = await _stt.initialize(
      onError: _onError,
      onStatus: _onStatus,
    );
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
    await _listen();
  }

  Future<void> stopListening() async {
    _wantListening = false;
    await _stt.stop();
    _setState(ListeningState.idle);
  }

  Future<void> _listen() async {
    if (!_wantListening || _stt.isListening) return;

    _setState(ListeningState.listening);

    await _stt.listen(
      onResult: _onResult,
      listenFor: const Duration(minutes: 5),
      pauseFor: const Duration(seconds: 4),
      localeId: 'en_US',
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
      ),
    );
  }

  void _onResult(SpeechRecognitionResult result) {
    final text = result.recognizedWords.trim();
    if (text.isNotEmpty) {
      _lastTranscript = text;
      _transcriptController.add(text);
    }
  }

  void _onStatus(String status) {
    // Restart automatically when the engine pauses/finishes
    if ((status == 'done' || status == 'notListening') && _wantListening) {
      Future.delayed(const Duration(milliseconds: 300), _listen);
    }
    if (status == 'listening') {
      _setState(ListeningState.listening);
    }
  }

  void _onError(SpeechRecognitionError error) {
    // Transient errors (e.g. "no speech") → just restart
    final transient = {'no-speech', 'audio', 'network'};
    if (transient.contains(error.errorMsg) && _wantListening) {
      Future.delayed(const Duration(seconds: 1), _listen);
    } else {
      _errorController.add('Recognition error: ${error.errorMsg}');
    }
  }

  void _setState(ListeningState s) {
    _state = s;
    _stateController.add(s);
  }

  void dispose() {
    _stt.stop();
    _transcriptController.close();
    _stateController.close();
    _errorController.close();
  }
}
