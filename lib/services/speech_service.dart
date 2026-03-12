import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:record/record.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum ListeningState { idle, initializing, listening, paused, error }

class SpeechService {
  // ── Deepgram config ────────────────────────────────────────────────────────
  static const String _apiKey = '041d7c9ddefd54080663f8c21c82e65ce6c2367d'; 

  static const String _wsUrl =
      'wss://api.deepgram.com/v1/listen'
      '?encoding=linear16'
      '&sample_rate=16000'
      '&channels=1'
      '&model=nova-3'          // best real-time model as of 2025
      '&language=en-US'
      '&interim_results=true'  // partial results as the person speaks
      '&punctuate=true'
      '&endpointing=300';      // ms of silence before finalising a segment

  // ── Internal state ─────────────────────────────────────────────────────────
  final _recorder = AudioRecorder();
  WebSocketChannel? _channel;
  StreamSubscription<Uint8List>? _audioSub;
  StreamSubscription<dynamic>? _wsSub;

  ListeningState _state = ListeningState.idle;
  ListeningState get state => _state;

  bool _wantListening = false;

  // ── Public streams ─────────────────────────────────────────────────────────
  final _transcriptController = StreamController<String>.broadcast();
  final _stateController = StreamController<ListeningState>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  Stream<String> get transcriptStream => _transcriptController.stream;
  Stream<ListeningState> get stateStream => _stateController.stream;
  Stream<String> get errorStream => _errorController.stream;

  // ── Transcript state ───────────────────────────────────────────────────────
  static const int _maxTranscriptChars = 500;
  String _lastTranscript = '';
  String get lastTranscript => _lastTranscript;
  String _stableTranscript = '';

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
      // IOWebSocketChannel lets us pass the Authorization header,
      // which is required by Deepgram (query-param auth is deprecated).
      _channel = IOWebSocketChannel.connect(
        Uri.parse(_wsUrl),
        headers: {'Authorization': 'Token $_apiKey'},
      );

      // Wait for the connection handshake to complete.
      await _channel!.ready;

      _setState(ListeningState.listening);

      // Listen for transcript events from Deepgram.
      _wsSub = _channel!.stream.listen(
        _onWsMessage,
        onError: _onWsError,
        onDone: _onWsDone,
      );

      // Start capturing microphone audio as raw 16-bit PCM.
      final audioStream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );

      // Forward every audio chunk straight to Deepgram.
      _audioSub = audioStream.listen(
        (Uint8List chunk) {
          try {
            _channel?.sink.add(chunk);
          } catch (_) {
            // Channel closed mid-stream — _onWsDone will handle reconnect.
          }
        },
        onError: (Object error) {
          _errorController.add('Audio capture error: $error');
        },
      );
    } catch (error) {
      _setState(ListeningState.error);
      _errorController.add('Could not connect to Deepgram: $error');
      // Retry after a short delay if the user still wants to listen.
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

    // Send Deepgram's close-stream signal before closing the socket.
    try {
      _channel?.sink.add('{"type":"CloseStream"}');
    } catch (_) {}
    await _channel?.sink.close();
    _channel = null;
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

    // Deepgram sends several message types; we only care about Results.
    final type = json['type'] as String?;
    if (type != 'Results') return;

    final channel = json['channel'] as Map<String, dynamic>?;
    final alternatives =
        channel?['alternatives'] as List<dynamic>?;
    if (alternatives == null || alternatives.isEmpty) return;

    final transcript =
        (alternatives.first as Map<String, dynamic>)['transcript'] as String?;
    if (transcript == null || transcript.trim().isEmpty) return;

    final isFinal = json['is_final'] as bool? ?? false;
    final speechFinal = json['speech_final'] as bool? ?? false;

    if (isFinal || speechFinal) {
      // Commit to stable transcript.
      _stableTranscript =
          _mergeTranscript(_stableTranscript, transcript.trim());
      _emitTranscript(_stableTranscript);
    } else {
      // Partial result — show stable + current live hypothesis.
      _emitTranscript(_mergeTranscript(_stableTranscript, transcript.trim()));
    }
  }

  void _onWsError(Object error) {
    _errorController.add('Deepgram connection error: $error');
    if (_wantListening) {
      Future.delayed(const Duration(seconds: 2), () {
        if (_wantListening) _connect();
      });
    }
  }

  void _onWsDone() {
    // Server closed the connection — reconnect if still wanted.
    if (_wantListening) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_wantListening) _connect();
      });
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

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

  /// Merges two transcript segments, de-duplicating overlapping words at the
  /// boundary (the same logic as before).
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
      final leftSlice =
          leftWords.sublist(leftWords.length - overlap).join(' ');
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
    _wantListening = false;
    _disconnect();
    _transcriptController.close();
    _stateController.close();
    _errorController.close();
  }
}