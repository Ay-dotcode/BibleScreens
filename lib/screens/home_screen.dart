import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/bible_verse.dart';
import '../services/bible_service.dart';
import '../services/speech_service.dart';
import '../services/verse_detector.dart';
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

  BibleVerse? _currentVerse;
  String _transcript = '';
  String _statusMessage = 'Press the mic to start listening';
  bool _isLoading = false;
  String? _errorMsg;

  VerseReference? _lastDetectedRef;

  // Subscriptions
  StreamSubscription<String>? _transcriptSub;
  StreamSubscription<ListeningState>? _stateSub;
  StreamSubscription<String>? _errorSub;

  // Animation
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _initAnimations();
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

    _transcriptSub = _speech.transcriptStream.listen(_onTranscript);
    _stateSub = _speech.stateStream.listen(_onStateChange);
    _errorSub = _speech.errorStream.listen(_onSpeechError);

    final ok = await _speech.init();
    if (!ok && mounted) {
      setState(() => _statusMessage =
          '⚠ Speech recognition unavailable — see README for setup');
    }
  }

  void _onTranscript(String text) {
    if (!mounted) return;
    setState(() => _transcript = text);

    // Detect verse in the latest transcript
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
      _lastDetectedRef = null; // reset so same verse can re-trigger
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
  }

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
                // ── Main verse display ──────────────────────────────────────────
                _buildVerseDisplay(horizontalPadding),

                // ── Top bar ─────────────────────────────────────────────────────
                _buildTopBar(horizontalPadding),

                // ── Bottom transcript panel ──────────────────────────────────────
                if (_settings.showTranscript)
                  _buildTranscriptPanel(horizontalPadding),

                // ── Error snackbar ───────────────────────────────────────────────
                if (_errorMsg != null) _buildErrorBanner(horizontalPadding),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVerseDisplay(double horizontalPadding) {
    return Center(
      child: Padding(
        padding:
            EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 120),
        child: _isLoading
            ? _buildLoader()
            : _currentVerse == null
                ? _buildPlaceholder()
                : _buildVerse(),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Decorative top line
          Container(
            width: 60,
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.white.withValues(alpha: 0.3),
                  Colors.transparent
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Verse text
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

          // Reference
          if (_settings.showReference)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 24,
                    height: 1,
                    color: _settings.refColor.withValues(alpha: 0.4)),
                const SizedBox(width: 12),
                Text(
                  _currentVerse!.reference.display,
                  style: TextStyle(
                    fontSize: _settings.refFontSize,
                    color: _settings.refColor,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                if (_settings.showTranslation) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: _settings.refColor.withValues(alpha: 0.3)),
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
                ],
                const SizedBox(width: 12),
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
                  Colors.transparent
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

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

            // Status label
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

            const SizedBox(width: 16),

            // Clear button
            if (_currentVerse != null)
              _iconBtn(Icons.clear_rounded, 'Clear', _clearDisplay),

            // Mic button
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

  @override
  void dispose() {
    _transcriptSub?.cancel();
    _stateSub?.cancel();
    _errorSub?.cancel();
    _speech.dispose();
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }
}
