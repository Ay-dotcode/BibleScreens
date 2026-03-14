import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:record/record.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum ListeningState { idle, initializing, listening, paused, error }

class SpeechService {
  // ── Deepgram config ────────────────────────────────────────────────────────
  static const String _apiKey = '041d7c9ddefd54080663f8c21c82e65ce6c2367d';

  static const String _wsUrl = 'wss://api.deepgram.com/v1/listen'
      '?encoding=linear16'
      '&sample_rate=16000'
      '&channels=1'
      '&model=nova-3'
      '&language=en-US'
      '&interim_results=true'
      '&punctuate=true'
      '&endpointing=300';

  // ── Internal state ─────────────────────────────────────────────────────────
  final _recorder = AudioRecorder();
  WebSocketChannel? _channel;
  StreamSubscription<Uint8List>? _audioSub;
  StreamSubscription<dynamic>? _wsSub;

  ListeningState _state = ListeningState.idle;
  ListeningState get state => _state;

  bool _wantListening = false;

  /// The microphone device to record from. null = system default.
  InputDevice? _selectedDevice;

  // ── Public streams ─────────────────────────────────────────────────────────
  final _transcriptController = StreamController<String>.broadcast();
  final _stateController = StreamController<ListeningState>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  /// Emits a normalised audio level in [0.0, 1.0] derived from RMS of each
  /// PCM chunk. Emits 0.0 when not recording.
  final _audioLevelController = StreamController<double>.broadcast();

  Stream<String> get transcriptStream => _transcriptController.stream;
  Stream<ListeningState> get stateStream => _stateController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<double> get audioLevelStream => _audioLevelController.stream;

  // ── Transcript state ───────────────────────────────────────────────────────
  static const int _maxTranscriptChars = 500;
  String _lastTranscript = '';
  String get lastTranscript => _lastTranscript;
  String _stableTranscript = '';

  // ── Microphone enumeration ─────────────────────────────────────────────────

  /// Returns all available audio input devices. May be empty on platforms
  /// where the record package does not support enumeration.
  Future<List<InputDevice>> listMicrophones() async {
    try {
      return await _recorder.listInputDevices();
    } catch (_) {
      return [];
    }
  }

  /// Switch to [device] (pass null to revert to the system default). If the
  /// service is currently listening the connection is cycled immediately.
  void setMicrophone(InputDevice? device) {
    _selectedDevice = device;
    if (_wantListening) {
      _disconnect().then((_) {
        if (_wantListening) _connect();
      });
    }
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<bool> init() async {
    _setState(ListeningState.initializing);

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _setState(ListeningState.error);
      _errorController.add(
        'Microphone permission denied. '
        'Allow microphone access in Windows Settings → Privacy → Microphone.',
      );
      return false;
    }

    _setState(ListeningState.idle);
    return true;
  }

  Future<void> startListening() async {
    if (_wantListening) return;
    _wantListening = true;
    _stableTranscript = '';
    _lastTranscript = '';
    await _connect();
  }

  Future<void> stopListening() async {
    _wantListening = false;
    await _disconnect();
    _setState(ListeningState.idle);
  }

  // ── Connection ─────────────────────────────────────────────────────────────

  Future<void> _connect() async {
    _setState(ListeningState.initializing);

    try {
      _channel = IOWebSocketChannel.connect(
        Uri.parse(_wsUrl),
        headers: {'Authorization': 'Token $_apiKey'},
      );

      await _channel!.ready;

      _setState(ListeningState.listening);

      _wsSub = _channel!.stream.listen(
        _onWsMessage,
        onError: _onWsError,
        onDone: _onWsDone,
      );

      // Start capturing microphone audio as raw 16-bit PCM.
      final audioStream = await _recorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          device: _selectedDevice, // null → system default
        ),
      );

      _audioSub = audioStream.listen(
        (Uint8List chunk) {
          // Forward audio to Deepgram.
          try {
            _channel?.sink.add(chunk);
          } catch (_) {
            // Channel closed mid-stream — _onWsDone will handle reconnect.
          }

          // Compute and broadcast the RMS level for the visualiser.
          if (!_audioLevelController.isClosed) {
            _audioLevelController.add(_rms(chunk));
          }
        },
        onError: (Object error) {
          _errorController.add('Audio capture error: $error');
        },
      );
    } catch (error) {
      _setState(ListeningState.error);
      _errorController.add('Could not connect to Deepgram: $error');
      if (_wantListening) {
        Future.delayed(const Duration(seconds: 2), () {
          if (_wantListening) _connect();
        });
      }
    }
  }

  Future<void> _disconnect() async {
    await _audioSub?.cancel();
    _audioSub = null;

    await _wsSub?.cancel();
    _wsSub = null;

    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }

    // Reset the visualiser.
    if (!_audioLevelController.isClosed) _audioLevelController.add(0.0);

    try {
      _channel?.sink.add('{"type":"CloseStream"}');
    } catch (_) {}
    await _channel?.sink.close();
    _channel = null;
  }

  // ── Audio level ────────────────────────────────────────────────────────────

  /// Computes the root-mean-square amplitude of a PCM-16 LE chunk and returns
  /// a value normalised to [0.0, 1.0].
  double _rms(Uint8List chunk) {
    final sampleCount = chunk.length ~/ 2;
    if (sampleCount == 0) return 0.0;

    double sumSq = 0.0;
    for (int i = 0; i < sampleCount * 2; i += 2) {
      // Reconstruct signed 16-bit sample (little-endian).
      int raw = chunk[i] | (chunk[i + 1] << 8);
      if (raw > 32767) raw -= 65536;
      sumSq += raw * raw;
    }

    return (sqrt(sumSq / sampleCount) / 32768.0).clamp(0.0, 1.0);
  }

  // ── WebSocket events ───────────────────────────────────────────────────────

  void _onWsMessage(dynamic raw) {
    if (raw is! String) return;

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final type = json['type'] as String?;
    if (type != 'Results') return;

    final channel = json['channel'] as Map<String, dynamic>?;
    final alternatives = channel?['alternatives'] as List<dynamic>?;
    if (alternatives == null || alternatives.isEmpty) return;

    final transcript =
        (alternatives.first as Map<String, dynamic>)['transcript'] as String?;
    if (transcript == null || transcript.trim().isEmpty) return;

    final isFinal = json['is_final'] as bool? ?? false;
    final speechFinal = json['speech_final'] as bool? ?? false;

    if (isFinal || speechFinal) {
      _stableTranscript =
          _mergeTranscript(_stableTranscript, transcript.trim());
      _emitTranscript(_stableTranscript);
    } else {
      _emitTranscript(_mergeTranscript(_stableTranscript, transcript.trim()));
    }
  }

  void _onWsError(Object error) {
    if (!_errorController.isClosed) {
      _errorController.add('Deepgram connection error: $error');
    }
    if (_wantListening) {
      Future.delayed(const Duration(seconds: 2), () {
        if (_wantListening) _connect();
      });
    }
  }

  void _onWsDone() {
    if (_wantListening) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_wantListening) _connect();
      });
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _setState(ListeningState s) {
    _state = s;
    if (!_stateController.isClosed) _stateController.add(s);
  }

  void _emitTranscript(String text) {
    final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.isEmpty) return;

    final clipped = compact.length <= _maxTranscriptChars
        ? compact
        : compact.substring(compact.length - _maxTranscriptChars);

    _lastTranscript = clipped;
    if (!_transcriptController.isClosed) _transcriptController.add(clipped);
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

  Future<void> dispose() async {
    _wantListening = false;
    await _disconnect();
    _transcriptController.close();
    _stateController.close();
    _errorController.close();
    _audioLevelController.close();
  }
}
