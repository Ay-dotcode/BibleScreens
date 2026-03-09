import 'dart:async';

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
  );

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final cached = await _bridge.readCurrent();
    if (cached != null && mounted) {
      setState(() => _state = cached);
    }

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

  @override
  Widget build(BuildContext context) {
    final verseColor = Color(_state.verseColor);
    final refColor = Color(_state.refColor);
    final bgColor = Color(_state.bgColor);
    final hasVerse = _state.verseText.trim().isNotEmpty;
    final hasBackgroundImage = _state.backgroundImageUrl.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (hasBackgroundImage)
            Image.network(
              _state.backgroundImageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          Container(
              color:
                  bgColor.withValues(alpha: hasBackgroundImage ? 0.45 : 1.0)),
          SafeArea(
            child: Center(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 72, vertical: 48),
                child: hasVerse
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '"${_state.verseText}"',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: _state.verseFontSize,
                              color: verseColor,
                              fontFamily: _state.fontFamily.isEmpty
                                  ? null
                                  : _state.fontFamily,
                              height: 1.45,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          if (_state.showReference &&
                              _state.reference.isNotEmpty) ...[
                            const SizedBox(height: 28),
                            Text(
                              _state.showTranslation &&
                                      _state.translation.isNotEmpty
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
                      )
                    : Text(
                        'Waiting for verse…',
                        style: TextStyle(
                          fontSize: 28,
                          color: verseColor.withValues(alpha: 0.25),
                          letterSpacing: 1.2,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
