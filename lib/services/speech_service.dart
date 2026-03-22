import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:record/record.dart';
import 'package:vosk_flutter_service/vosk_flutter.dart';

import '../utils/bible_grammar.dart';
import 'vosk_model_service.dart';

enum ListeningState { idle, initializing, listening, paused, error }

class SpeechService {
  final _transcriptCtrl = StreamController<String>.broadcast();
  final _stateCtrl = StreamController<ListeningState>.broadcast();
  final _errorCtrl = StreamController<String>.broadcast();
  final _audioLevelCtrl = StreamController<double>.broadcast();

  Stream<String> get transcriptStream => _transcriptCtrl.stream;
  Stream<ListeningState> get stateStream => _stateCtrl.stream;
  Stream<String> get errorStream => _errorCtrl.stream;
  Stream<double> get audioLevelStream => _audioLevelCtrl.stream;

  ListeningState _state = ListeningState.idle;
  ListeningState get state => _state;

  final _vosk = VoskFlutterPlugin.instance();
  Model? _model;
  Recognizer? _recognizer;

  dynamic _androidSpeechService;
  StreamSubscription<String>? _androidResultSub;
  StreamSubscription<String>? _androidPartialSub;

  final _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _pcmSub;

  bool _initialized = false;
  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  // Minimum average confidence across all words in a result.
  // Results below this are discarded as likely false positives from
  // ambient speech being forced into Bible vocabulary.
  static const double _minConfidence = 0.75;

  // ── Mic selection ──────────────────────────────────────────────────────────
  List<InputDevice> _availableMics = [];
  InputDevice? _selectedMic;

  Future<List<InputDevice>> listMicrophones() async {
    _availableMics = await _recorder.listInputDevices();
    return _availableMics;
  }

  void setMicrophone(InputDevice? mic) => _selectedMic = mic;

  // ── Init ───────────────────────────────────────────────────────────────────

  Future<bool> init() async {
    if (_initialized) return true;
    _emitState(ListeningState.initializing);

    try {
      final modelSvc = VoskModelService.instance;
      if (!await modelSvc.isDownloaded(kDefaultModel)) {
        _emitState(ListeningState.idle);
        _errorCtrl.add('model_not_downloaded');
        return false;
      }

      final path = await modelSvc.modelPath(kDefaultModel);
      _model = await _vosk.createModel(path);

      // Grammar mode: restrict Vosk to Bible book names + numbers only.
      // Combined with confidence filtering this prevents ambient speech
      // from being misheard as verse references.
      _recognizer = await _vosk.createRecognizer(
        model: _model!,
        sampleRate: 16000,
        grammar: kBibleGrammar,
      );

      _initialized = true;
      _emitState(ListeningState.idle);
      return true;
    } catch (e) {
      _emitState(ListeningState.error);
      _errorCtrl.add('Vosk init failed: $e');
      return false;
    }
  }

  // ── Listening ──────────────────────────────────────────────────────────────

  Future<void> startListening() async {
    if (!_initialized) {
      final ok = await init();
      if (!ok) return;
    }
    _emitState(ListeningState.listening);
    _isDesktop ? await _startDesktop() : await _startAndroid();
  }

  Future<void> stopListening() async {
    _isDesktop ? await _stopDesktop() : await _stopAndroid();
    _audioLevelCtrl.add(0.0);
    _emitState(ListeningState.idle);
  }

  // ── Desktop ────────────────────────────────────────────────────────────────

  Future<void> _startDesktop() async {
    try {
      if (!await _recorder.hasPermission()) {
        _emitState(ListeningState.error);
        _errorCtrl.add('Microphone permission denied');
        return;
      }

      final stream = await _recorder.startStream(RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        device: _selectedMic,
      ));

      _pcmSub = stream.listen(
        (chunk) async {
          if (_recognizer == null) return;
          final ready = await _recognizer!.acceptWaveformBytes(chunk);
          if (ready) {
            // Final results include per-word confidence — filter low confidence
            final text = _parseWithConfidence(await _recognizer!.getResult());
            if (text.isNotEmpty) _transcriptCtrl.add(text);
          } else {
            // Partials have no confidence scores — show as-is in transcript
            // strip but VerseDetector will only act on final results
            final text =
                _parseText(await _recognizer!.getPartialResult(), 'partial');
            if (text.isNotEmpty) _transcriptCtrl.add(text);
          }
          _audioLevelCtrl.add(_rms(chunk));
        },
        onError: (e) {
          _errorCtrl.add('Mic stream error: $e');
          _emitState(ListeningState.error);
        },
      );
    } catch (e) {
      _emitState(ListeningState.error);
      _errorCtrl.add('Could not start microphone: $e');
    }
  }

  Future<void> _stopDesktop() async {
    await _pcmSub?.cancel();
    _pcmSub = null;
    await _recorder.stop();
    if (_recognizer != null) {
      final text = _parseWithConfidence(await _recognizer!.getFinalResult());
      if (text.isNotEmpty) _transcriptCtrl.add(text);
    }
  }

  // ── Android ────────────────────────────────────────────────────────────────

  Future<void> _startAndroid() async {
    _androidSpeechService = await _vosk.initSpeechService(_recognizer!);
    _androidResultSub = _androidSpeechService.onResult().listen((e) {
      final text = _parseWithConfidence(e);
      if (text.isNotEmpty) _transcriptCtrl.add(text);
    });
    _androidPartialSub = _androidSpeechService.onPartial().listen((e) {
      final text = _parseText(e, 'partial');
      if (text.isNotEmpty) _transcriptCtrl.add(text);
    });
    await _androidSpeechService.start();
  }

  Future<void> _stopAndroid() async {
    await _androidResultSub?.cancel();
    await _androidPartialSub?.cancel();
    await _androidSpeechService?.stop();
    await _androidSpeechService?.dispose();
    _androidSpeechService = null;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Parses a Vosk final result JSON and returns the text only if the
  /// average per-word confidence meets [_minConfidence].
  ///
  /// Vosk result format with word-level confidence:
  /// {
  ///   "result": [
  ///     {"conf": 0.92, "word": "john"},
  ///     {"conf": 0.88, "word": "three"},
  ///     {"conf": 0.95, "word": "sixteen"}
  ///   ],
  ///   "text": "john three sixteen"
  /// }
  String _parseWithConfidence(String json) {
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      final text = (map['text'] as String? ?? '').trim();
      if (text.isEmpty) return '';

      final results = map['result'] as List<dynamic>?;
      if (results == null || results.isEmpty) {
        // No per-word scores available — fall back to returning the text
        return text;
      }

      double totalConf = 0;
      int count = 0;
      for (final w in results) {
        final conf = (w as Map<String, dynamic>)['conf'];
        if (conf != null) {
          totalConf += (conf as num).toDouble();
          count++;
        }
      }

      if (count == 0) return text;
      final avgConf = totalConf / count;
      return avgConf >= _minConfidence ? text : '';
    } catch (_) {
      return '';
    }
  }

  String _parseText(String json, String key) {
    try {
      return ((jsonDecode(json) as Map<String, dynamic>)[key] as String? ?? '')
          .trim();
    } catch (_) {
      return '';
    }
  }

  double _rms(Uint8List bytes) {
    if (bytes.length < 2) return 0;
    final samples = bytes.buffer.asInt16List();
    double sum = 0;
    for (final s in samples) {
      sum += s * s;
    }
    return ((sum / samples.length) / (32768.0 * 32768.0)).clamp(0.0, 1.0);
  }

  void _emitState(ListeningState s) {
    _state = s;
    _stateCtrl.add(s);
  }

  // ── Dispose ────────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    await _pcmSub?.cancel();
    await _recorder.dispose();
    await _androidResultSub?.cancel();
    await _androidPartialSub?.cancel();
    await _androidSpeechService?.stop();
    await _androidSpeechService?.dispose();
    _recognizer?.dispose();
    _model?.dispose();
    await _transcriptCtrl.close();
    await _stateCtrl.close();
    await _errorCtrl.close();
    await _audioLevelCtrl.close();
  }
}
