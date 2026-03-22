import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';

import '../models/app_settings.dart';
import '../models/bible_verse.dart';
import '../models/second_display_state.dart';
import '../services/bible_service.dart';
import '../services/second_display_bridge.dart';
import '../services/speech_service.dart';
import '../services/verse_detector.dart';
import '../widgets/vosk_model_download_widget.dart';
import 'settings_screen.dart';
import 'song_search_screen.dart';

// ── Local data types ───────────────────────────────────────────────────────

class _HistoryEntry {
  final BibleVerse verse;
  final DateTime time;
  _HistoryEntry(this.verse) : time = DateTime.now();
}

// ── Widget ─────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // ── Services ───────────────────────────────────────────────────────────────
  final _speech = SpeechService();
  final _bible = BibleService();
  final _settings = AppSettings.instance;
  final _displayBridge = SecondDisplayBridge();

  // ── Live output ────────────────────────────────────────────────────────────
  BibleVerse? _currentVerse;
  String _transcript = '';
  String _statusMessage = 'Press the mic to start listening';

  // ── Intent deduplication ───────────────────────────────────────────────────
  String _lastIntentKey = '';

  // ── Live verse range (auto-detected from speech) ───────────────────────────
  // When a range like "Genesis 1:2-5" is detected, all verses are loaded here.
  // The display auto-advances through them as the preacher reads.
  List<BibleVerse> _liveRange = [];
  int _liveRangeIndex = 0;

  // Transcript accumulated since the current verse was pushed to the display.
  // Used for auto-advance word matching.
  String _transcriptSincePush = '';

  // ── Queue & history ────────────────────────────────────────────────────────
  final List<BibleVerse> _queue = [];
  final List<_HistoryEntry> _history = [];
  static const int _maxHistory = 20;

  // ── Manual search ──────────────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  BibleVerse? _searchResult;
  bool _searchLoading = false;
  String? _searchError;

  // ── Lyrics ─────────────────────────────────────────────────────────────────
  final _lyricsCtrl = TextEditingController();
  final _lyricsFocusNode = FocusNode();
  List<String> _lyricsSlides = [];
  int _currentLyricsSlide = -1;

  // ── Audio ──────────────────────────────────────────────────────────────────
  double _audioLevel = 0.0;
  List<InputDevice> _availableMics = [];
  InputDevice? _selectedMic;

  // ── Vosk model ─────────────────────────────────────────────────────────────
  bool _needsModelDownload = false;

  // ── Subscriptions ──────────────────────────────────────────────────────────
  StreamSubscription<String>? _transcriptSub;
  StreamSubscription<ListeningState>? _stateSub;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<double>? _audioLevelSub;

  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late VoidCallback _settingsListener;

  // ── Tabs ───────────────────────────────────────────────────────────────────
  late TabController _tabCtrl;

  // ─────────────────────────────────────────────────────────────────────────
  // Stopwords for auto-advance word matching
  // ─────────────────────────────────────────────────────────────────────────

  static const _stopwords = {
    'the',
    'a',
    'an',
    'and',
    'or',
    'but',
    'in',
    'on',
    'at',
    'to',
    'for',
    'of',
    'with',
    'is',
    'was',
    'are',
    'were',
    'be',
    'been',
    'being',
    'have',
    'has',
    'had',
    'do',
    'does',
    'did',
    'will',
    'would',
    'could',
    'should',
    'may',
    'might',
    'shall',
    'can',
    'that',
    'this',
    'it',
    'he',
    'she',
    'they',
    'we',
    'you',
    'i',
    'his',
    'her',
    'their',
    'our',
    'your',
    'my',
    'its',
    'not',
    'no',
    'so',
    'if',
    'as',
    'by',
    'up',
    'out',
    'then',
    'than',
    'also',
    'into',
    'from',
    'upon',
  };

  Set<String> _significantWords(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.length > 2 && !_stopwords.contains(w))
      .toSet();

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(_pulseCtrl);

    _settingsListener = () {
      if (mounted) setState(() {});
      _publishToSecondDisplay();
    };
    _settings.addListener(_settingsListener);
    _initServices();
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    _settings.removeListener(_settingsListener);
    _transcriptSub?.cancel();
    _stateSub?.cancel();
    _errorSub?.cancel();
    _audioLevelSub?.cancel();
    _speech.dispose();
    _displayBridge.dispose();
    _pulseCtrl.dispose();
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _lyricsCtrl.dispose();
    _lyricsFocusNode.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Initialisation
  // ─────────────────────────────────────────────────────────────────────────

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
      setState(() =>
          _statusMessage = '⚠ Microphone unavailable — check permissions');
    }

    final mics = await _speech.listMicrophones();
    if (mounted) setState(() => _availableMics = mics);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Stream handlers
  // ─────────────────────────────────────────────────────────────────────────

  void _onTranscript(String text) {
    if (!mounted) return;
    setState(() {
      _transcript = text;
      _transcriptSincePush = '$_transcriptSincePush $text';
    });

    final intent = VerseDetector.detectIntent(
      text,
      inVerseMode: _currentVerse != null,
    );

    if (intent == null) {
      _checkAutoAdvance();
      return;
    }

    final key = _intentKey(intent);

    // Always process navigation (preacher may say "next" multiple times)
    final isNav = intent is NavigationIntent;
    if (!isNav && key == _lastIntentKey) {
      _checkAutoAdvance();
      return;
    }
    _lastIntentKey = key;

    switch (intent) {
      case VerseIntent(:final ref):
        _liveRange = [];
        _liveRangeIndex = 0;
        _autoFetchAndDisplay(ref);

      case VerseRangeIntent(:final start, :final endVerse):
        _autoFetchRangeAndDisplay(start, endVerse);

      case NavigationIntent(:final action, :final targetVerse):
        _handleNavigation(action, targetVerse);

      case TranslationIntent(:final translationId):
        _handleTranslationSwitch(translationId);
    }
  }

  String _intentKey(DetectedIntent intent) => switch (intent) {
        VerseIntent(:final ref) =>
          'verse-${ref.book}-${ref.chapter}-${ref.verse}',
        VerseRangeIntent(:final start, :final endVerse) =>
          'range-${start.book}-${start.chapter}-${start.verse}-$endVerse',
        NavigationIntent(:final action, :final targetVerse) =>
          'nav-$action-$targetVerse',
        TranslationIntent(:final translationId) => 'trans-$translationId',
      };

  void _onStateChange(ListeningState state) {
    if (!mounted) return;
    setState(() {
      _statusMessage = switch (state) {
        ListeningState.listening => '🎙 Listening…',
        ListeningState.paused => '⏸ Paused',
        ListeningState.idle => 'Press mic to start listening',
        ListeningState.initializing => 'Initializing…',
        ListeningState.error => '⚠ Error — check mic setup',
      };
    });
  }

  void _onSpeechError(String error) {
    if (!mounted) return;
    if (error == 'model_not_downloaded') {
      setState(() => _needsModelDownload = true);
    } else {
      _showError(error);
    }
  }

  void _onAudioLevel(double level) {
    if (!mounted) return;
    setState(() => _audioLevel = level);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Auto-advance through verse range
  // ─────────────────────────────────────────────────────────────────────────

  /// Checks whether the preacher has read enough of the current verse to
  /// advance to the next one in the range.
  ///
  /// Compares significant words from the verse text against the transcript
  /// accumulated since the verse was pushed. Advances when ≥65% match.
  void _checkAutoAdvance() {
    if (_liveRange.length <= 1) return;
    if (_liveRangeIndex >= _liveRange.length - 1) return;
    if (_currentVerse == null) return;

    final verseWords = _significantWords(_currentVerse!.text);
    if (verseWords.isEmpty) return;

    final spokenWords = _significantWords(_transcriptSincePush);
    final matched = verseWords.where(spokenWords.contains).length;
    final ratio = matched / verseWords.length;

    if (ratio >= 0.65) {
      _liveRangeIndex++;
      _pushLive(_liveRange[_liveRangeIndex]);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Navigation commands
  // ─────────────────────────────────────────────────────────────────────────

  void _handleNavigation(NavigationAction action, int? targetVerse) {
    switch (action) {
      case NavigationAction.next:
        if (_liveRange.isNotEmpty && _liveRangeIndex < _liveRange.length - 1) {
          // Advance within detected range
          _liveRangeIndex++;
          _pushLive(_liveRange[_liveRangeIndex]);
        } else if (_currentVerse != null) {
          // No range — go to next verse in same chapter
          final ref = _currentVerse!.reference;
          _autoFetchAndDisplay(VerseReference(
            book: ref.book,
            chapter: ref.chapter,
            verse: ref.verse + 1,
          ));
        }

      case NavigationAction.specific:
        if (targetVerse == null) return;
        if (_currentVerse != null) {
          final ref = _currentVerse!.reference;
          _autoFetchAndDisplay(VerseReference(
            book: ref.book,
            chapter: ref.chapter,
            verse: targetVerse,
          ));
        }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Translation switching
  // ─────────────────────────────────────────────────────────────────────────

  void _handleTranslationSwitch(String translationId) {
    if (_settings.translation == translationId) return;
    _settings.translation = translationId;
    _showSnack('Translation → ${translationId.toUpperCase()}');

    // Re-fetch current verse in the new translation
    if (_currentVerse != null) {
      _autoFetchAndDisplay(_currentVerse!.reference);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Hotkeys
  // ─────────────────────────────────────────────────────────────────────────

  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (_searchFocusNode.hasFocus || _lyricsFocusNode.hasFocus) return false;

    final key = event.logicalKey;
    final ctrl = HardwareKeyboard.instance.isControlPressed;

    if (key == LogicalKeyboardKey.escape) {
      _clearOutput();
      return true;
    }
    if (key == LogicalKeyboardKey.f5) {
      _toggleListening();
      return true;
    }
    if (key == LogicalKeyboardKey.space) {
      if (_queue.isNotEmpty) {
        _pushFromQueue(0);
        return true;
      }
      if (_searchResult != null) {
        _pushLive(_searchResult!);
        return true;
      }
      return false;
    }
    if (ctrl && key == LogicalKeyboardKey.keyF) {
      _tabCtrl.animateTo(0);
      _searchFocusNode.requestFocus();
      return true;
    }
    if (key == LogicalKeyboardKey.arrowDown && _queue.isNotEmpty) {
      _pushFromQueue(0);
      return true;
    }
    return false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Output actions
  // ─────────────────────────────────────────────────────────────────────────

  bool get _isLiveVerse =>
      _currentVerse != null && _currentVerse!.reference.chapter > 0;

  void _pushLive(BibleVerse verse) {
    setState(() {
      _currentVerse = verse;
      _transcriptSincePush = ''; // reset auto-advance tracking
      _history.insert(0, _HistoryEntry(verse));
      if (_history.length > _maxHistory) _history.removeLast();
    });
    _publishToSecondDisplay();
  }

  void _clearOutput() {
    setState(() {
      _currentVerse = null;
      _liveRange = [];
      _liveRangeIndex = 0;
      _transcriptSincePush = '';
      _lastIntentKey = '';
    });
    _publishToSecondDisplay();
  }

  void _clearAll() {
    setState(() {
      _currentVerse = null;
      _transcript = '';
      _liveRange = [];
      _liveRangeIndex = 0;
      _transcriptSincePush = '';
      _lastIntentKey = '';
      _searchResult = null;
    });
    _publishToSecondDisplay();
  }

  void _pushTextSlide(String text) {
    _pushLive(BibleVerse(
      reference: const VerseReference(book: '', chapter: 0, verse: 0),
      text: text,
      translation: '',
    ));
  }

  // ── Queue ──────────────────────────────────────────────────────────────────

  void _addToQueue(BibleVerse verse) => setState(() => _queue.add(verse));

  void _pushFromQueue(int index) {
    if (index < 0 || index >= _queue.length) return;
    final verse = _queue[index];
    setState(() => _queue.removeAt(index));
    _liveRange = [];
    _liveRangeIndex = 0;
    _pushLive(verse);
  }

  void _removeFromQueue(int index) {
    if (index < 0 || index >= _queue.length) return;
    setState(() => _queue.removeAt(index));
  }

  void _moveQueueUp(int index) {
    if (index <= 0 || index >= _queue.length) return;
    setState(() {
      final v = _queue.removeAt(index);
      _queue.insert(index - 1, v);
    });
  }

  void _moveQueueDown(int index) {
    if (index < 0 || index >= _queue.length - 1) return;
    setState(() {
      final v = _queue.removeAt(index);
      _queue.insert(index + 1, v);
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Fetch helpers
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _autoFetchAndDisplay(VerseReference ref) async {
    try {
      _bible.translation = _settings.translation;
      final verse = await _bible.fetchVerse(ref);
      if (!mounted) return;
      _pushLive(verse);
    } catch (_) {}
  }

  /// Fetches all verses from [start] through [endVerse] in the same chapter,
  /// displays the first immediately, and stores the rest for auto-advance.
  Future<void> _autoFetchRangeAndDisplay(
      VerseReference start, int endVerse) async {
    try {
      _bible.translation = _settings.translation;
      final verses = <BibleVerse>[];
      for (var v = start.verse; v <= endVerse; v++) {
        final verse = await _bible.fetchVerse(
          VerseReference(book: start.book, chapter: start.chapter, verse: v),
        );
        verses.add(verse);
      }
      if (!mounted || verses.isEmpty) return;
      setState(() {
        _liveRange = verses;
        _liveRangeIndex = 0;
      });
      _pushLive(verses.first);
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Manual search
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _performSearch() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _searchLoading = true;
      _searchError = null;
      _searchResult = null;
    });

    try {
      final ref = VerseDetector.detect(query);
      if (ref == null) {
        setState(() {
          _searchLoading = false;
          _searchError = 'Enter a valid reference — e.g. John 3:16 or Psalm 23';
        });
        return;
      }
      _bible.translation = _settings.translation;
      final verse = await _bible.fetchVerse(ref);
      if (!mounted) return;
      setState(() {
        _searchResult = verse;
        _searchLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchLoading = false;
        _searchError = 'Could not load verse';
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Lyrics
  // ─────────────────────────────────────────────────────────────────────────

  void _splitLyrics() {
    final text = _lyricsCtrl.text.trim();
    if (text.isEmpty) return;
    final slides = text
        .split(RegExp(r'\n\s*\n'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    setState(() {
      _lyricsSlides = slides;
      _currentLyricsSlide = slides.isEmpty ? -1 : 0;
    });
  }

  void _pushLyricsSlide() {
    if (_currentLyricsSlide < 0 ||
        _currentLyricsSlide >= _lyricsSlides.length) {
      return;
    }
    _pushTextSlide(_lyricsSlides[_currentLyricsSlide]);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Mic
  // ─────────────────────────────────────────────────────────────────────────

  void _toggleListening() async {
    if (_needsModelDownload) return;
    if (_speech.state == ListeningState.listening) {
      await _speech.stopListening();
    } else {
      _lastIntentKey = '';
      await _speech.startListening();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Second display
  // ─────────────────────────────────────────────────────────────────────────

  SecondDisplayState _currentDisplayState() {
    final isLyrics =
        _currentVerse != null && _currentVerse!.reference.chapter == 0;
    return SecondDisplayState(
      verseText: _currentVerse?.text ?? '',
      reference: isLyrics ? '' : (_currentVerse?.reference.display ?? ''),
      translation: isLyrics ? '' : (_currentVerse?.translation ?? ''),
      showReference: _settings.showReference,
      showTranslation: _settings.showTranslation,
      bgColor: _settings.bgColor.toARGB32(),
      verseColor: _settings.verseColor.toARGB32(),
      refColor: _settings.refColor.toARGB32(),
      verseFontSize: _settings.verseFontSize,
      refFontSize: _settings.refFontSize,
      fontFamily: _settings.fontFamily,
      backgroundImageUrl: _settings.outputBackgroundImageUrl,
      localBackgroundImagePath: _settings.localBackgroundImagePath,
      transitionType: _settings.outputTransition,
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
          const SnackBar(content: Text('Second display opened.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open second display: $e')));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Utilities
  // ─────────────────────────────────────────────────────────────────────────

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red.shade900));
  }

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _settings,
      builder: (context, _) => Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Column(
          children: [
            _buildTopBar(theme, isDark),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 55, child: _buildLeftPanel(theme, isDark)),
                  Container(width: 1, color: theme.dividerColor),
                  Expanded(flex: 45, child: _buildRightPanel(theme)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Top bar
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTopBar(ThemeData theme, bool isDark) {
    final isListening = _speech.state == ListeningState.listening;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Text('Church Display',
              style: TextStyle(
                  fontSize: 14,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w300,
                  color: theme.textTheme.bodySmall?.color)),
          const SizedBox(width: 16),
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Opacity(
              opacity: isListening ? _pulseAnim.value : 1.0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isListening
                      ? Colors.green.withValues(alpha: 0.15)
                      : theme.dividerColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isListening
                          ? Colors.green.withValues(alpha: 0.5)
                          : Colors.transparent),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                        isListening
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 9,
                        color: isListening
                            ? Colors.green
                            : theme.textTheme.bodySmall?.color),
                    const SizedBox(width: 5),
                    Text(_statusMessage,
                        style: TextStyle(
                            fontSize: 11,
                            color: isListening
                                ? Colors.green
                                : theme.textTheme.bodySmall?.color)),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          _hotkeyHint('Space', 'Push queue'),
          _hotkeyHint('Esc', 'Clear'),
          _hotkeyHint('F5', 'Mic'),
          _hotkeyHint('Ctrl+F', 'Search'),
          const SizedBox(width: 8),
          Tooltip(
            message: isDark ? 'Switch to light mode' : 'Switch to dark mode',
            child: IconButton(
              icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
              onPressed: () {
                _settings.applyThemeMode(
                  isDark ? ThemeMode.light : ThemeMode.dark,
                  platformBrightness: MediaQuery.platformBrightnessOf(context),
                );
              },
            ),
          ),
          Tooltip(
            message: 'Settings',
            child: IconButton(
              icon: const Icon(Icons.settings_rounded),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hotkeyHint(String key, String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Tooltip(
        message: label,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
          ),
          child: Text(key,
              style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey.withValues(alpha: 0.5),
                  fontFamily: 'monospace')),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Left panel
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildLeftPanel(ThemeData theme, bool isDark) {
    return Column(
      children: [
        Expanded(flex: 5, child: _buildLivePreview(theme, isDark)),
        Container(height: 1, color: theme.dividerColor),
        _buildTranscriptStrip(theme),
        Container(height: 1, color: theme.dividerColor),
        _buildMicControls(theme),
      ],
    );
  }

  // ── Live preview ───────────────────────────────────────────────────────────

  Widget _buildLivePreview(ThemeData theme, bool isDark) {
    final hasContent = _currentVerse != null;
    final isLive = hasContent && _isLiveVerse;
    final previewBg = _settings.bgColor;
    final verseColor = _settings.verseColor;
    final refColor = _settings.refColor;
    final hasLocalImg =
        !kIsWeb && _settings.localBackgroundImagePath.isNotEmpty;

    return Stack(
      children: [
        Positioned.fill(child: Container(color: previewBg)),
        if (hasLocalImg)
          Positioned.fill(
            child: Image.file(
              File(_settings.localBackgroundImagePath),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        if (hasLocalImg)
          Positioned.fill(
              child: Container(color: previewBg.withValues(alpha: 0.5))),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              child: hasContent
                  ? Column(
                      key: ValueKey(_currentVerse!.reference.display),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentVerse!.text,
                          textAlign: TextAlign.center,
                          maxLines: 8,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: ((_settings.verseFontSize / 3.5)
                                .clamp(14.0, 22.0)),
                            color: verseColor,
                            fontFamily: _settings.fontFamily.isEmpty
                                ? null
                                : _settings.fontFamily,
                            height: 1.45,
                          ),
                        ),
                        if (isLive && _settings.showReference) ...[
                          const SizedBox(height: 10),
                          Text(
                            _settings.showTranslation
                                ? '${_currentVerse!.reference.display}  ·  ${_currentVerse!.translation}'
                                : _currentVerse!.reference.display,
                            style: TextStyle(
                              fontSize: 12,
                              color: refColor,
                              letterSpacing: 1,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ],
                      ],
                    )
                  : Text(
                      key: const ValueKey('empty'),
                      'Output is clear — no verse showing',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
            ),
          ),
        ),
        if (hasContent)
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.circle, size: 7, color: Colors.white),
                SizedBox(width: 4),
                Text('LIVE',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2)),
              ]),
            ),
          ),
        // Range progress indicator
        if (_liveRange.length > 1)
          Positioned(
            top: 10,
            left: 70,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${_liveRangeIndex + 1} / ${_liveRange.length}',
                style: const TextStyle(
                    color: Colors.white70, fontSize: 10, letterSpacing: 0.5),
              ),
            ),
          ),
        Positioned(
          top: 8,
          right: 8,
          child: Row(
            children: [
              _previewBtn(Icons.open_in_new_rounded, 'Open second display',
                  _openSecondDisplay),
              if (hasContent) ...[
                const SizedBox(width: 4),
                _previewBtn(Icons.clear_rounded, 'Clear output', _clearOutput),
              ],
            ],
          ),
        ),
        Positioned(
          bottom: 8,
          left: 10,
          child: Text('LIVE PREVIEW',
              style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 2,
                  color: Colors.white.withValues(alpha: 0.2))),
        ),
      ],
    );
  }

  Widget _previewBtn(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 15, color: Colors.white70),
        ),
      ),
    );
  }

  // ── Transcript strip ───────────────────────────────────────────────────────

  Widget _buildTranscriptStrip(ThemeData theme) {
    final hasText = _transcript.isNotEmpty;
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.hearing_rounded,
                size: 11,
                color:
                    theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5)),
            const SizedBox(width: 5),
            Text('LIVE TRANSCRIPT',
                style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 2,
                    color: theme.textTheme.bodySmall?.color
                        ?.withValues(alpha: 0.5))),
          ]),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              hasText ? _transcript : '…',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: hasText
                    ? theme.textTheme.bodyMedium?.color
                    : theme.textTheme.bodySmall?.color?.withValues(alpha: 0.3),
                fontStyle: hasText ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Mic controls ───────────────────────────────────────────────────────────

  Widget _buildMicControls(ThemeData theme) {
    if (_needsModelDownload) {
      return VoskModelDownloadWidget(
        onReady: () async {
          setState(() => _needsModelDownload = false);
          final ok = await _speech.init();
          if (!ok && mounted) {
            _showError(
                'Model downloaded but failed to load — restart the app.');
          }
        },
      );
    }

    final isListening = _speech.state == ListeningState.listening;

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: theme.cardColor,
      child: Row(
        children: [
          Tooltip(
            message:
                isListening ? 'Stop listening (F5)' : 'Start listening (F5)',
            child: InkWell(
              onTap: _toggleListening,
              borderRadius: BorderRadius.circular(30),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isListening
                      ? Colors.red.withValues(alpha: 0.2)
                      : theme.dividerColor,
                  border: Border.all(
                      color: isListening
                          ? Colors.red.withValues(alpha: 0.6)
                          : Colors.transparent),
                ),
                child: Icon(
                  isListening ? Icons.mic_off_rounded : Icons.mic_rounded,
                  color: isListening ? Colors.red : theme.iconTheme.color,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _CompactAudioMeter(level: _audioLevel),
          const SizedBox(width: 10),
          if (_availableMics.isNotEmpty) _buildMicDropdown(theme),
          const Spacer(),
          Tooltip(
            message: 'Clear transcript and output',
            child: IconButton(
              icon: const Icon(Icons.layers_clear_rounded, size: 18),
              onPressed: _clearAll,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicDropdown(ThemeData theme) {
    String label(InputDevice? mic) {
      if (mic == null) return 'Default mic';
      final n = mic.label;
      return n.length > 24 ? '${n.substring(0, 22)}…' : n;
    }

    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<InputDevice?>(
          value: _selectedMic,
          isDense: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              size: 15, color: theme.textTheme.bodySmall?.color),
          selectedItemBuilder: (_) => [
            _micLabel(label(null), theme),
            ..._availableMics.map((m) => _micLabel(label(m), theme)),
          ],
          items: [
            DropdownMenuItem<InputDevice?>(
                value: null,
                child: _micMenuItem(
                    'Default (system)', _selectedMic == null, theme)),
            ..._availableMics.map((m) => DropdownMenuItem<InputDevice?>(
                value: m,
                child: _micMenuItem(m.label, _selectedMic?.id == m.id, theme))),
          ],
          onChanged: (mic) {
            setState(() => _selectedMic = mic);
            _speech.setMicrophone(mic);
          },
        ),
      ),
    );
  }

  Widget _micLabel(String text, ThemeData theme) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mic_rounded,
              size: 12, color: theme.textTheme.bodySmall?.color),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  fontSize: 11, color: theme.textTheme.bodySmall?.color)),
        ],
      );

  Widget _micMenuItem(String label, bool selected, ThemeData theme) => Row(
        children: [
          Icon(selected ? Icons.check_rounded : Icons.mic_none_rounded,
              size: 15,
              color:
                  selected ? Colors.green : theme.textTheme.bodySmall?.color),
          const SizedBox(width: 8),
          Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      color: theme.textTheme.bodyMedium?.color,
                      fontWeight:
                          selected ? FontWeight.w500 : FontWeight.w400))),
        ],
      );

  // ─────────────────────────────────────────────────────────────────────────
  // Right panel
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildRightPanel(ThemeData theme) {
    return Column(
      children: [
        Container(
          color: theme.cardColor,
          child: TabBar(
            controller: _tabCtrl,
            tabs: const [
              Tab(icon: Icon(Icons.menu_book_rounded, size: 16), text: 'Bible'),
              Tab(
                  icon: Icon(Icons.music_note_rounded, size: 16),
                  text: 'Lyrics'),
              Tab(
                  icon: Icon(Icons.library_music_rounded, size: 16),
                  text: 'Songs'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildBibleTab(theme),
              _buildLyricsTab(theme),
              SongSearchScreen(onSlidePush: _pushTextSlide),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Bible tab
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBibleTab(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _sectionHeader('Search (Ctrl+F)', theme),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocusNode,
              style: TextStyle(
                  fontSize: 14, color: theme.textTheme.bodyMedium?.color),
              decoration: InputDecoration(
                hintText: 'e.g. John 3:16 or Genesis 1:2-5',
                prefixIcon: Icon(Icons.search_rounded,
                    size: 18, color: theme.textTheme.bodySmall?.color),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
              onSubmitted: (_) => _performSearch(),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _searchLoading ? null : _performSearch,
            style: FilledButton.styleFrom(
                minimumSize: const Size(60, 42), padding: EdgeInsets.zero),
            child: _searchLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.arrow_forward_rounded, size: 18),
          ),
        ]),
        if (_searchError != null) ...[
          const SizedBox(height: 6),
          Text(_searchError!,
              style: const TextStyle(color: Colors.red, fontSize: 12)),
        ],
        if (_searchResult != null) ...[
          const SizedBox(height: 10),
          _verseCard(
            verse: _searchResult!,
            theme: theme,
            onPushLive: () => _pushLive(_searchResult!),
            onAddQueue: () {
              _addToQueue(_searchResult!);
              _showSnack('Added to queue');
            },
          ),
        ],
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _sectionHeader('Queue (${_queue.length})', theme),
          if (_queue.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => _queue.clear()),
              style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact),
              child: const Text('Clear', style: TextStyle(fontSize: 11)),
            ),
        ]),
        const SizedBox(height: 6),
        if (_queue.isEmpty)
          _emptyHint(
              'Add verses from search or history.\nSpace = push top item.',
              theme)
        else
          ...List.generate(
              _queue.length, (i) => _queueItem(_queue[i], i, theme)),
        const SizedBox(height: 16),
        _sectionHeader('History (${_history.length})', theme),
        const SizedBox(height: 6),
        if (_history.isEmpty)
          _emptyHint('Verses sent to the output will appear here.', theme)
        else
          ..._history.map((e) => _historyItem(e, theme)),
      ],
    );
  }

  Widget _verseCard({
    required BibleVerse verse,
    required ThemeData theme,
    VoidCallback? onPushLive,
    VoidCallback? onAddQueue,
  }) {
    final isLyrics = verse.reference.chapter == 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isLyrics)
            Text(verse.reference.display,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                    letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(verse.text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13,
                  color: theme.textTheme.bodyMedium?.color,
                  height: 1.4)),
          const SizedBox(height: 8),
          Row(children: [
            if (onPushLive != null)
              _smallAction(
                  Icons.play_arrow_rounded, 'Push live', onPushLive, theme,
                  primary: true),
            if (onAddQueue != null) ...[
              const SizedBox(width: 6),
              _smallAction(Icons.queue_rounded, '+ Queue', onAddQueue, theme),
            ],
          ]),
        ],
      ),
    );
  }

  Widget _queueItem(BibleVerse verse, int i, ThemeData theme) {
    final isLyrics = verse.reference.chapter == 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('${i + 1}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isLyrics)
                  Text(verse.reference.display,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary)),
                Text(verse.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodyMedium?.color)),
              ],
            ),
          ),
          const SizedBox(width: 4),
          _iconAction(Icons.arrow_upward_rounded, () => _moveQueueUp(i), theme,
              tooltip: 'Move up'),
          _iconAction(
              Icons.arrow_downward_rounded, () => _moveQueueDown(i), theme,
              tooltip: 'Move down'),
          _iconAction(Icons.play_arrow_rounded, () => _pushFromQueue(i), theme,
              tooltip: 'Push live', color: theme.colorScheme.primary),
          _iconAction(Icons.close_rounded, () => _removeFromQueue(i), theme,
              tooltip: 'Remove', color: Colors.red),
        ],
      ),
    );
  }

  Widget _historyItem(_HistoryEntry entry, ThemeData theme) {
    final isLyrics = entry.verse.reference.chapter == 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isLyrics)
                  Text(entry.verse.reference.display,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.bodySmall?.color)),
                Text(entry.verse.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodyMedium?.color)),
              ],
            ),
          ),
          Text(_formatTime(entry.time),
              style: TextStyle(
                  fontSize: 10,
                  color: theme.textTheme.bodySmall?.color
                      ?.withValues(alpha: 0.5))),
          const SizedBox(width: 6),
          _iconAction(
              Icons.play_arrow_rounded, () => _pushLive(entry.verse), theme,
              tooltip: 'Push live again', color: theme.colorScheme.primary),
          _iconAction(Icons.queue_rounded, () {
            _addToQueue(entry.verse);
            _showSnack('Added to queue');
          }, theme, tooltip: 'Add to queue'),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Lyrics tab
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildLyricsTab(ThemeData theme) {
    return Column(
      children: [
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader('Lyrics editor', theme),
                const SizedBox(height: 4),
                Text('Separate slides with a blank line.',
                    style: TextStyle(
                        fontSize: 11, color: theme.textTheme.bodySmall?.color)),
                const SizedBox(height: 8),
                Expanded(
                  child: TextField(
                    controller: _lyricsCtrl,
                    focusNode: _lyricsFocusNode,
                    maxLines: null,
                    expands: true,
                    style: TextStyle(
                        fontSize: 13,
                        color: theme.textTheme.bodyMedium?.color,
                        height: 1.5),
                    decoration: const InputDecoration(
                      hintText:
                          'Paste lyrics here…\n\nEach paragraph becomes one slide.',
                      alignLabelWithHint: true,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  FilledButton.icon(
                    onPressed: _splitLyrics,
                    icon: const Icon(Icons.call_split_rounded, size: 16),
                    label: const Text('Split into slides'),
                  ),
                  const SizedBox(width: 8),
                  if (_lyricsSlides.isNotEmpty)
                    OutlinedButton(
                      onPressed: () => setState(() {
                        _lyricsSlides = [];
                        _currentLyricsSlide = -1;
                      }),
                      child: const Text('Clear'),
                    ),
                ]),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ),
        Container(height: 1, color: theme.dividerColor),
        Expanded(
          flex: 3,
          child: _lyricsSlides.isEmpty
              ? Center(
                  child: Text('Split your lyrics above to create slides.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: theme.textTheme.bodySmall?.color,
                          fontSize: 13)))
              : Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _sectionHeader('Slides', theme),
                                Text(
                                    'Slide ${_currentLyricsSlide + 1} / ${_lyricsSlides.length}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color:
                                            theme.textTheme.bodySmall?.color)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_currentLyricsSlide >= 0)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  _lyricsSlides[_currentLyricsSlide],
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: theme.textTheme.bodyMedium?.color,
                                      height: 1.5),
                                ),
                              ),
                            const SizedBox(height: 10),
                            Row(children: [
                              IconButton.outlined(
                                onPressed: _currentLyricsSlide > 0
                                    ? () =>
                                        setState(() => _currentLyricsSlide--)
                                    : null,
                                icon: const Icon(Icons.chevron_left_rounded),
                                tooltip: 'Previous slide',
                              ),
                              const Spacer(),
                              FilledButton.icon(
                                onPressed: _currentLyricsSlide >= 0
                                    ? _pushLyricsSlide
                                    : null,
                                icon: const Icon(Icons.play_arrow_rounded,
                                    size: 18),
                                label: const Text('Push live'),
                              ),
                              const Spacer(),
                              IconButton.outlined(
                                onPressed: _currentLyricsSlide <
                                        _lyricsSlides.length - 1
                                    ? () =>
                                        setState(() => _currentLyricsSlide++)
                                    : null,
                                icon: const Icon(Icons.chevron_right_rounded),
                                tooltip: 'Next slide',
                              ),
                            ]),
                          ],
                        ),
                      ),
                    ),
                    Container(height: 1, color: theme.dividerColor),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        itemCount: _lyricsSlides.length,
                        itemBuilder: (_, i) {
                          final isCurrent = i == _currentLyricsSlide;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _currentLyricsSlide = i),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? theme.colorScheme.primary
                                        .withValues(alpha: 0.12)
                                    : theme.cardColor,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: isCurrent
                                        ? theme.colorScheme.primary
                                            .withValues(alpha: 0.4)
                                        : theme.dividerColor),
                              ),
                              child: Row(children: [
                                Text('${i + 1}',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: isCurrent
                                            ? theme.colorScheme.primary
                                            : theme
                                                .textTheme.bodySmall?.color)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(_lyricsSlides[i],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: theme
                                              .textTheme.bodyMedium?.color)),
                                ),
                                if (isCurrent)
                                  Icon(Icons.play_arrow_rounded,
                                      size: 14,
                                      color: theme.colorScheme.primary),
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Shared UI helpers
  // ─────────────────────────────────────────────────────────────────────────

  Widget _sectionHeader(String title, ThemeData theme) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
          fontSize: 9,
          letterSpacing: 2,
          fontWeight: FontWeight.w600,
          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6)),
    );
  }

  Widget _emptyHint(String msg, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(msg,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12,
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                fontStyle: FontStyle.italic)),
      ),
    );
  }

  Widget _smallAction(
      IconData icon, String label, VoidCallback onTap, ThemeData theme,
      {bool primary = false}) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      style: OutlinedButton.styleFrom(
        foregroundColor: primary
            ? theme.colorScheme.primary
            : theme.textTheme.bodySmall?.color,
        side: BorderSide(
            color: primary
                ? theme.colorScheme.primary.withValues(alpha: 0.5)
                : theme.dividerColor),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _iconAction(IconData icon, VoidCallback onTap, ThemeData theme,
      {String? tooltip, Color? color}) {
    return IconButton(
      icon: Icon(icon,
          size: 16,
          color: color ??
              theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6)),
      onPressed: onTap,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(4),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact inline audio VU meter
// ─────────────────────────────────────────────────────────────────────────────

class _CompactAudioMeter extends StatelessWidget {
  const _CompactAudioMeter({required this.level});

  final double level;

  static const List<double> _factors = [
    0.40,
    0.65,
    0.80,
    1.00,
    0.90,
    0.72,
    0.55,
    0.85,
    0.60,
    0.95,
    0.48,
    0.75,
    0.62,
    0.88,
    0.50,
  ];

  static double _boost(double r) => 0.04 + r * 0.96;

  static Color _barColor(double fraction) {
    if (fraction > 0.85) return const Color(0xFFFF3B30);
    if (fraction > 0.65) return const Color(0xFFFFCC00);
    return const Color(0xFF30D158);
  }

  @override
  Widget build(BuildContext context) {
    final boosted = _boost(level);
    const maxH = 28.0;

    return SizedBox(
      width: _factors.length * 7.0,
      height: maxH,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(_factors.length, (i) {
          final targetH = (_factors[i] * boosted * maxH).clamp(2.0, maxH);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 70),
              curve: Curves.easeOut,
              width: 3,
              height: targetH,
              decoration: BoxDecoration(
                color: _barColor(targetH / maxH),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(2)),
              ),
            ),
          );
        }),
      ),
    );
  }
}
