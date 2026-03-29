import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'sherpa_model_service.dart';

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

  sherpa.OnlineRecognizer? _recognizer;
  sherpa.OnlineStream? _stream;

  final _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _pcmSub;

  bool _initialized = false;

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
      final svc = SherpaModelService.instance;
      if (!await svc.isDownloaded(kDefaultSherpaModel)) {
        _emitState(ListeningState.idle);
        _errorCtrl.add('model_not_downloaded');
        return false;
      }

      final encoder = await svc.encoderPath(kDefaultSherpaModel);
      final decoder = await svc.decoderPath(kDefaultSherpaModel);
      final joiner = await svc.joinerPath(kDefaultSherpaModel);
      final tokens = await svc.tokensPath(kDefaultSherpaModel);

      // OnlineModelConfig uses `transducer` for zipformer transducer models.
      // `zipformer2` refers only to CTC variants — transducer is correct here.
      final modelConfig = sherpa.OnlineModelConfig(
        transducer: sherpa.OnlineTransducerModelConfig(
          encoder: encoder,
          decoder: decoder,
          joiner: joiner,
        ),
        tokens: tokens,
        numThreads: Platform.numberOfProcessors.clamp(1, 4),
        modelType: 'zipformer2',
        debug: false,
      );

      final config = sherpa.OnlineRecognizerConfig(
        model: modelConfig,
        enableEndpoint: true,
        rule1MinTrailingSilence: 2.4,
        rule2MinTrailingSilence: 1.2,
        rule3MinUtteranceLength: 20.0,
        decodingMethod: 'greedy_search',
        maxActivePaths: 4,
      );

      _recognizer = sherpa.OnlineRecognizer(config);
      _stream = _recognizer!.createStream();

      _initialized = true;
      _emitState(ListeningState.idle);
      return true;
    } catch (e) {
      _emitState(ListeningState.error);
      _errorCtrl.add('Sherpa init failed: $e');
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
    await _startMic();
  }

  Future<void> stopListening() async {
    await _pcmSub?.cancel();
    _pcmSub = null;
    await _recorder.stop();
    _audioLevelCtrl.add(0.0);
    _emitState(ListeningState.idle);
  }

  Future<void> _startMic() async {
    try {
      if (!await _recorder.hasPermission()) {
        _emitState(ListeningState.error);
        _errorCtrl.add('Microphone permission denied');
        return;
      }

      final audioStream = await _recorder.startStream(RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        device: _selectedMic,
      ));

      _pcmSub = audioStream.listen(
        _onAudioChunk,
        onError: (e) {
          _errorCtrl.add('Mic error: $e');
          _emitState(ListeningState.error);
        },
      );
    } catch (e) {
      _emitState(ListeningState.error);
      _errorCtrl.add('Could not start microphone: $e');
    }
  }

  void _onAudioChunk(Uint8List bytes) {
    if (_recognizer == null || _stream == null) return;

    // Convert Int16 PCM bytes → Float32 samples normalised to [-1, 1]
    final int16 = bytes.buffer.asInt16List();
    final float32 = Float32List(int16.length);
    for (var i = 0; i < int16.length; i++) {
      float32[i] = int16[i] / 32768.0;
    }

    _stream!.acceptWaveform(samples: float32, sampleRate: 16000);

    // Decode all pending frames
    while (_recognizer!.isReady(_stream!)) {
      _recognizer!.decode(_stream!);
    }

    // Emit current (partial or final) transcript text
    final result = _recognizer!.getResult(_stream!);
    if (result.text.isNotEmpty) {
      _transcriptCtrl.add(result.text.trim());
    }

    // On detected endpoint (natural pause) reset so next utterance starts fresh
    if (_recognizer!.isEndpoint(_stream!)) {
      _recognizer!.reset(_stream!);
    }

    _audioLevelCtrl.add(_rms(bytes));
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

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
    _stream?.free();
    _recognizer?.free();
    await _transcriptCtrl.close();
    await _stateCtrl.close();
    await _errorCtrl.close();
    await _audioLevelCtrl.close();
  }
}
