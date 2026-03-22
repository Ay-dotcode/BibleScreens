import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/second_display_state.dart';
import '../services/second_display_bridge.dart';

class OutputDisplayScreen extends StatefulWidget {
  const OutputDisplayScreen({super.key});

  @override
  State<OutputDisplayScreen> createState() => _OutputDisplayScreenState();
}

class _OutputDisplayScreenState extends State<OutputDisplayScreen> {
  final _bridge = SecondDisplayBridge();
  StreamSubscription<SecondDisplayState>? _subscription;

  SecondDisplayState _state = SecondDisplayState.empty(
    bgColor: const Color(0xFF0A0A14).toARGB32(),
    verseColor: Colors.white.toARGB32(),
    refColor: const Color(0xFFB0BEC5).toARGB32(),
    verseFontSize: 52,
    refFontSize: 28,
    fontFamily: 'Georgia',
    backgroundImageUrl: '',
    localBackgroundImagePath: '',
    transitionType: 'crossfade',
  );

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final cached = await _bridge.readCurrent();
    if (cached != null && mounted) setState(() => _state = cached);

    _subscription = _bridge.listen().listen((next) {
      if (!mounted) return;
      setState(() => _state = next);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _bridge.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool get _hasVerse => _state.verseText.trim().isNotEmpty;

  /// Resolve the background image widget — prefer the locally cached copy.
  Widget _backgroundImage() {
    // Local path (downloaded/picked) takes priority
    final local = _state.localBackgroundImagePath;
    if (!kIsWeb && local.isNotEmpty) {
      final f = File(local);
      if (f.existsSync()) {
        return Image.file(f,
            fit: BoxFit.cover, width: double.infinity, height: double.infinity);
      }
    }
    // Fall back to original network URL
    final url = _state.backgroundImageUrl;
    if (url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }
    return const SizedBox.shrink();
  }

  bool get _hasBackground =>
      (!kIsWeb && _state.localBackgroundImagePath.isNotEmpty) ||
      _state.backgroundImageUrl.isNotEmpty;

  /// Build the transition for the AnimatedSwitcher.
  Widget _wrapTransition(Widget child, Animation<double> anim) {
    switch (_state.transitionType) {
      case 'slideUp':
        return SlideTransition(
          position: Tween(begin: const Offset(0, 0.18), end: Offset.zero)
              .animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim, child: child),
        );
      case 'fadeBlack':
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeInOutCubic),
          child: child,
        );
      default: // crossfade
        return FadeTransition(opacity: anim, child: child);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bgColor = Color(_state.bgColor);
    final verseColor = Color(_state.verseColor);
    final refColor = Color(_state.refColor);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background image ──────────────────────────────────────────────
          if (_hasBackground) _backgroundImage(),

          // ── Dim overlay (ensures text is readable over any image) ─────────
          Container(
              color: bgColor.withValues(alpha: _hasBackground ? 0.45 : 1.0)),

          // ── Verse / lyrics (animated transition) ──────────────────────────
          SafeArea(
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 550),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: _wrapTransition,
                child: _hasVerse
                    ? _buildVerseContent(
                        verseColor: verseColor, refColor: refColor)
                    // When nothing is queued, show completely blank — no text.
                    : const SizedBox.shrink(key: ValueKey('empty')),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerseContent({
    required Color verseColor,
    required Color refColor,
  }) {
    final isLyrics = _state.reference.isEmpty;

    return Padding(
      key: ValueKey('${_state.reference}|${_state.verseText.hashCode}'),
      padding: const EdgeInsets.symmetric(horizontal: 72, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            isLyrics ? _state.verseText : '"${_state.verseText}"',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: _state.verseFontSize,
              color: verseColor,
              fontFamily: _state.fontFamily.isEmpty ? null : _state.fontFamily,
              height: 1.45,
              fontWeight: FontWeight.w400,
            ),
          ),
          if (!isLyrics &&
              _state.showReference &&
              _state.reference.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(
              _state.showTranslation && _state.translation.isNotEmpty
                  ? '${_state.reference}  ·  ${_state.translation.toUpperCase()}'
                  : _state.reference,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: _state.refFontSize,
                color: refColor,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
