import 'dart:async';

import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../models/app_settings.dart';
import '../models/bible_verse.dart';
import '../models/second_display_state.dart';
import '../services/bible_service.dart';
import '../services/second_display_bridge.dart';
import '../services/speech_service.dart';
import '../services/verse_detector.dart';
// ignore: unused_import
import '../utils/color_compat.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _speech = SpeechService();
  final _bible = BibleService();
  final _settings = AppSettings.instance;
  final _displayBridge = SecondDisplayBridge();

  BibleVerse? _currentVerse;
  String _transcript = '';
  String _statusMessage = 'Press the mic to start listening';
  bool _isLoading = false;
  String? _errorMsg;

  VerseReference? _lastDetectedRef;

  // ── Subscriptions ──────────────────────────────────────────────────────────
  StreamSubscription<String>? _transcriptSub;
  StreamSubscription<ListeningState>? _stateSub;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<double>? _audioLevelSub;

  // ── Microphone state ───────────────────────────────────────────────────────
  List<InputDevice> _availableMics = [];
  InputDevice? _selectedMic; // null = system default

  // ── Audio level visualiser ─────────────────────────────────────────────────
  double _audioLevel = 0.0;

  // ── Animation ─────────────────────────────────────────────────────────────
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late VoidCallback _settingsSyncListener;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _settingsSyncListener = () => _publishToSecondDisplay();
    _settings.addListener(_settingsSyncListener);
    _initServices();
  }

  void _initAnimations() {
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(_pulseCtrl);
  }

  Future<void> _initServices() async {
    await _settings.load();
    await _bible.init();
    await _publishToSecondDisplay();

    _transcriptSub = _speech.transcriptStream.listen(_onTranscript);
    _stateSub = _speech.stateStream.listen(_onStateChange);
    _errorSub = _speech.errorStream.listen(_onSpeechError);
    _audioLevelSub = _speech.audioLevelStream.listen(_onAudioLevel);

    final ok = await _speech.init();
    if (!ok && mounted) {
      setState(() => _statusMessage =
          '⚠ Speech recognition unavailable — see README for setup');
    }

    // Enumerate microphones after init (permission should be granted by now).
    final mics = await _speech.listMicrophones();
    if (mounted) setState(() => _availableMics = mics);
  }

  // ── Stream handlers ────────────────────────────────────────────────────────

  void _onTranscript(String text) {
    if (!mounted) return;
    setState(() => _transcript = text);

    final ref = VerseDetector.detect(text);
    if (ref != null && ref != _lastDetectedRef) {
      _lastDetectedRef = ref;
      _fetchAndDisplay(ref);
    }
  }

  void _onStateChange(ListeningState state) {
    if (!mounted) return;
    setState(() {
      switch (state) {
        case ListeningState.listening:
          _statusMessage = '🎙 Listening…';
          break;
        case ListeningState.paused:
          _statusMessage = '⏸ Paused…';
          break;
        case ListeningState.idle:
          _statusMessage = 'Press the mic to start listening';
          break;
        case ListeningState.initializing:
          _statusMessage = 'Initializing microphone…';
          break;
        case ListeningState.error:
          _statusMessage = '⚠ Error — check README for platform setup';
          break;
      }
    });
  }

  void _onSpeechError(String error) {
    if (!mounted) return;
    setState(() => _errorMsg = error);
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _errorMsg = null);
    });
  }

  void _onAudioLevel(double level) {
    if (!mounted) return;
    setState(() => _audioLevel = level);
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _fetchAndDisplay(VerseReference ref) async {
    setState(() {
      _isLoading = true;
      _fadeCtrl.reset();
    });

    try {
      _bible.translation = _settings.translation;
      final verse = await _bible.fetchVerse(ref);
      if (!mounted) return;
      setState(() {
        _currentVerse = verse;
        _isLoading = false;
      });
      _fadeCtrl.forward();
      await _publishToSecondDisplay();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMsg = 'Could not load ${ref.display} — check internet connection';
      });
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _errorMsg = null);
      });
    }
  }

  void _toggleListening() async {
    if (_speech.state == ListeningState.listening) {
      await _speech.stopListening();
    } else {
      _lastDetectedRef = null;
      await _speech.startListening();
    }
  }

  void _clearDisplay() {
    setState(() {
      _currentVerse = null;
      _transcript = '';
      _lastDetectedRef = null;
    });
    _fadeCtrl.reset();
    _publishToSecondDisplay();
  }

  void _clearOutputOnly() {
    setState(() {
      _currentVerse = null;
      _lastDetectedRef = null;
    });
    _fadeCtrl.reset();
    _publishToSecondDisplay();
  }

  SecondDisplayState _currentDisplayState() {
    return SecondDisplayState(
      verseText: _currentVerse?.text ?? '',
      reference: _currentVerse?.reference.display ?? '',
      translation: _currentVerse?.translation ?? '',
      showReference: _settings.showReference,
      showTranslation: _settings.showTranslation,
      bgColor: _settings.bgColor.toARGB32(),
      verseColor: _settings.verseColor.toARGB32(),
      refColor: _settings.refColor.toARGB32(),
      verseFontSize: _settings.verseFontSize,
      refFontSize: _settings.refFontSize,
      fontFamily: _settings.fontFamily,
      backgroundImageUrl: _settings.outputBackgroundImageUrl,
    );
  }

  Future<void> _publishToSecondDisplay() async {
    await _displayBridge.publish(_currentDisplayState());
  }

  Future<void> _openSecondDisplay() async {
    try {
      await _displayBridge.openDisplayWindow();
      await _publishToSecondDisplay();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Second display opened/updated.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open second display: $error')),
      );
    }
  }

  Future<void> _changeOutputBackgroundImage() async {
    final controller =
        TextEditingController(text: _settings.outputBackgroundImageUrl);

    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text('Output background image URL'),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white70),
            decoration: const InputDecoration(
              hintText: 'https://.../background.jpg',
              hintStyle: TextStyle(color: Colors.white38),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(''),
              child: const Text('Clear image'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    if (value == null) return;
    _settings.update((s) => s.outputBackgroundImageUrl = value);
    await _publishToSecondDisplay();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final horizontalPadding = screenWidth >= 1600
            ? 180.0
            : screenWidth >= 1200
                ? 120.0
                : screenWidth >= 900
                    ? 72.0
                    : 24.0;

        return AnimatedBuilder(
          animation: _settings,
          builder: (context, _) => Scaffold(
            backgroundColor: _settings.bgColor,
            body: Stack(
              children: [
                _buildVerseDisplay(horizontalPadding),
                _buildTopBar(horizontalPadding),
                if (_settings.showTranscript)
                  _buildTranscriptPanel(horizontalPadding),
                if (_errorMsg != null) _buildErrorBanner(horizontalPadding),
                // Bottom-right audio visualiser — always in the tree so it
                // fades smoothly; the widget handles its own visibility.
                _buildAudioVisualizer(constraints),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Verse display ──────────────────────────────────────────────────────────

  Widget _buildVerseDisplay(double horizontalPadding) {
    final verticalPadding = _settings.showTranscript ? 110.0 : 80.0;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final content = _isLoading
              ? _buildLoader()
              : _currentVerse == null
                  ? _buildPlaceholder()
                  : _buildVerse();

          final minContentHeight =
              (constraints.maxHeight - (verticalPadding * 2))
                  .clamp(0.0, double.infinity);

          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minContentHeight),
                child: Center(child: content),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            color: Colors.white.withValues(alpha: 0.5),
            strokeWidth: 2,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Loading verse…',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4), fontSize: 18),
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.church_rounded,
          size: 80,
          color: Colors.white.withValues(alpha: 0.06),
        ),
        const SizedBox(height: 24),
        Text(
          'Church Display',
          style: TextStyle(
            fontSize: 36,
            color: Colors.white.withValues(alpha: 0.08),
            letterSpacing: 4,
            fontWeight: FontWeight.w300,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Speak a Bible verse — it will appear here automatically',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withValues(alpha: 0.15),
          ),
        ),
      ],
    );
  }

  Widget _buildVerse() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxContentWidth =
              constraints.maxWidth > 1200 ? 1200.0 : constraints.maxWidth;

          return ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 60,
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  '"${_currentVerse!.text}"',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: _settings.verseFontSize,
                    color: _settings.verseColor,
                    fontFamily: _settings.fontFamily,
                    height: 1.45,
                    fontWeight: FontWeight.w400,
                    shadows: [
                      Shadow(
                        blurRadius: 40,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                if (_settings.showReference)
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Container(
                          width: 24,
                          height: 1,
                          color: _settings.refColor.withValues(alpha: 0.4)),
                      Text(
                        _currentVerse!.reference.display,
                        style: TextStyle(
                          fontSize: _settings.refFontSize,
                          color: _settings.refColor,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      if (_settings.showTranslation)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color:
                                    _settings.refColor.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _currentVerse!.translation,
                            style: TextStyle(
                              fontSize: 13,
                              color: _settings.refColor.withValues(alpha: 0.7),
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      Container(
                          width: 24,
                          height: 1,
                          color: _settings.refColor.withValues(alpha: 0.4)),
                    ],
                  ),
                const SizedBox(height: 32),
                Container(
                  width: 60,
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar(double horizontalPadding) {
    final isListening = _speech.state == ListeningState.listening;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding:
            EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _settings.bgColor.withValues(alpha: 0.95),
              _settings.bgColor.withValues(alpha: 0.0),
            ],
          ),
        ),
        child: Row(
          children: [
            // App name
            Text(
              'Church Display',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 14,
                letterSpacing: 2,
                fontWeight: FontWeight.w300,
              ),
            ),

            const Spacer(),

            // Status pill
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Opacity(
                opacity: isListening ? _pulseAnim.value : 1.0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: isListening
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isListening
                          ? Colors.green.withValues(alpha: 0.4)
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isListening
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 10,
                        color: isListening
                            ? Colors.green
                            : Colors.white.withValues(alpha: 0.3),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _statusMessage,
                        style: TextStyle(
                          color: isListening
                              ? Colors.green
                              : Colors.white.withValues(alpha: 0.4),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // ── Microphone selector ──────────────────────────────────────────
            if (_availableMics.isNotEmpty) _buildMicSelector(),

            const SizedBox(width: 4),

            // Clear button
            if (_currentVerse != null)
              _iconBtn(Icons.clear_rounded, 'Clear', _clearDisplay),

            _iconBtn(Icons.open_in_new_rounded, 'Open second display',
                _openSecondDisplay),

            _iconBtn(Icons.layers_clear_rounded, 'Clear output screen',
                _clearOutputOnly),

            _iconBtn(Icons.image_rounded, 'Output background image',
                _changeOutputBackgroundImage),

            // Mic toggle button
            _micButton(isListening),

            // Settings button
            _iconBtn(Icons.settings_rounded, 'Settings', () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()));
            }),
          ],
        ),
      ),
    );
  }

  // ── Bottom-right audio visualiser panel ───────────────────────────────────

  /// A narrow tall VU meter pinned to the bottom-right, ~1/3 screen height.
  Widget _buildAudioVisualizer(BoxConstraints screenConstraints) {
    final panelHeight = screenConstraints.maxHeight / 3;

    // Meter is 22 px wide. Give it 12 px breathing room from the screen edge.
    const meterWidth = 22.0;

    return Positioned(
      bottom: 20,
      right: 36,
      width: meterWidth,
      height: panelHeight,
      child: AnimatedOpacity(
        opacity: 1.0,
        duration: const Duration(milliseconds: 400),
        child: IgnorePointer(
          child: _VerticalAudioVisualizer(
            level: _audioLevel,
            totalHeight: panelHeight,
            meterWidth: meterWidth,
          ),
        ),
      ),
    );
  }

  /// Compact mic-selector dropdown that lives directly in the top bar.
  Widget _buildMicSelector() {
    // Truncate long device names for the button label.
    String label(InputDevice? mic) {
      if (mic == null) return 'Default';
      final name = mic.label;
      return name.length > 22 ? '${name.substring(0, 20)}…' : name;
    }

    return Tooltip(
      message: 'Select microphone',
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<InputDevice?>(
            value: _selectedMic,
            isDense: true,
            dropdownColor: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(8),
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: Colors.white.withValues(alpha: 0.35),
            ),
            // Current selection display
            selectedItemBuilder: (_) => [
              // "null" = default
              _micDropdownLabel(Icons.mic_rounded, label(null)),
              // one entry per real device
              ..._availableMics.map(
                  (mic) => _micDropdownLabel(Icons.mic_rounded, label(mic))),
            ],
            // Menu items
            items: [
              DropdownMenuItem<InputDevice?>(
                value: null,
                child: _micMenuItem('Default (system)',
                    isSelected: _selectedMic == null),
              ),
              ..._availableMics.map(
                (mic) => DropdownMenuItem<InputDevice?>(
                  value: mic,
                  child: _micMenuItem(
                    mic.label,
                    isSelected: _selectedMic?.id == mic.id,
                  ),
                ),
              ),
            ],
            onChanged: (mic) {
              setState(() => _selectedMic = mic);
              _speech.setMicrophone(mic);
            },
          ),
        ),
      ),
    );
  }

  /// The compact label shown inside the dropdown button when collapsed.
  Widget _micDropdownLabel(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.4)),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  /// A single menu item in the expanded dropdown.
  Widget _micMenuItem(String label, {required bool isSelected}) {
    return Row(
      children: [
        Icon(
          isSelected ? Icons.check_rounded : Icons.mic_none_rounded,
          size: 16,
          color: isSelected
              ? Colors.green.withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.3),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  Widget _micButton(bool isListening) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: isListening ? 'Stop listening' : 'Start listening',
        child: InkWell(
          onTap: _toggleListening,
          borderRadius: BorderRadius.circular(30),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isListening
                  ? Colors.red.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.08),
              border: Border.all(
                color: isListening
                    ? Colors.red.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.15),
              ),
            ),
            child: Icon(
              isListening ? Icons.mic_off_rounded : Icons.mic_rounded,
              color: isListening
                  ? Colors.red
                  : Colors.white.withValues(alpha: 0.6),
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, String tooltip, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: tooltip,
        child: IconButton(
          icon: Icon(icon, size: 20),
          color: Colors.white.withValues(alpha: 0.4),
          hoverColor: Colors.white.withValues(alpha: 0.08),
          onPressed: onTap,
        ),
      ),
    );
  }

  // ── Transcript panel ───────────────────────────────────────────────────────

  Widget _buildTranscriptPanel(double horizontalPadding) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Opacity(
        opacity: _settings.transcriptOpacity,
        child: Container(
          padding:
              EdgeInsets.fromLTRB(horizontalPadding, 20, horizontalPadding, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: 0.8),
                Colors.transparent,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.hearing_rounded,
                      size: 14, color: Colors.white.withValues(alpha: 0.3)),
                  const SizedBox(width: 6),
                  Text(
                    'LIVE TRANSCRIPT',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.3),
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _transcript.isEmpty ? '…' : _transcript,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.55),
                  fontStyle:
                      _transcript.isEmpty ? FontStyle.italic : FontStyle.normal,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Error banner ───────────────────────────────────────────────────────────

  Widget _buildErrorBanner(double horizontalPadding) {
    return Positioned(
      bottom: _settings.showTranscript ? 100 : 20,
      left: horizontalPadding,
      right: horizontalPadding,
      child: AnimatedOpacity(
        opacity: _errorMsg != null ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.red.shade900.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white70, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _errorMsg ?? '',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Dispose ────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _settings.removeListener(_settingsSyncListener);
    _transcriptSub?.cancel();
    _stateSub?.cancel();
    _errorSub?.cancel();
    _audioLevelSub?.cancel();
    _speech
        .dispose(); // async fire-and-forget is fine here — streams are guarded
    _displayBridge.dispose();
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }
}

// ── Vertical mixer-style level meter ──────────────────────────────────────

/// A single column of horizontal segments that light up from the bottom,
/// exactly like a channel-strip VU meter on an audio mixer.
class _VerticalAudioVisualizer extends StatelessWidget {
  const _VerticalAudioVisualizer({
    required this.level,
    required this.totalHeight,
    required this.meterWidth,
  });

  final double level;
  final double totalHeight;
  final double meterWidth;

  static const int _segmentCount = 30;
  static const double _gap = 2.5;

  static Color _segmentColor(double fractionFromBottom, bool lit) {
    final Color base;
    if (fractionFromBottom > 0.85) {
      base = const Color(0xFFFF3B30); // red  — peak
    } else if (fractionFromBottom > 0.65) {
      base = const Color(0xFFFFCC00); // amber — caution
    } else {
      base = const Color(0xFF30D158); // green — nominal
    }
    return lit ? base : base.withValues(alpha: 0.10);
  }

  @override
  Widget build(BuildContext context) {
    final litCount = (level * _segmentCount).round().clamp(0, _segmentCount);

    // Divide total height evenly across segments + gaps.
    final segmentH =
        ((totalHeight - _gap * (_segmentCount - 1)) / _segmentCount)
            .clamp(2.0, double.infinity);

    return SizedBox(
      width: meterWidth,
      height: totalHeight,
      child: Column(
        // Build top→bottom; segments lit from the bottom up.
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(_segmentCount, (i) {
          final fractionFromBottom = 1.0 - i / (_segmentCount - 1);
          final rankFromBottom = _segmentCount - 1 - i;
          final lit = rankFromBottom < litCount;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 60),
            curve: Curves.easeOut,
            width: meterWidth,
            height: segmentH,
            decoration: BoxDecoration(
              color: _segmentColor(fractionFromBottom, lit),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }
}
