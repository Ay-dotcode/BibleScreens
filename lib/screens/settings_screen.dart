import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../services/bible_service.dart';
// ignore: unused_import
import '../utils/color_compat.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = AppSettings.instance;
  final _bible = BibleService();

  bool _offlineDownloading = false;
  double _offlineProgress = 0;
  String _offlineLabel = '';

  @override
  void initState() {
    super.initState();
    _bible.init();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settings,
      builder: (context, _) => Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F0F1A),
          title: const Text(
            'Settings',
            style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.w300),
          ),
          iconTheme: const IconThemeData(color: Colors.white60),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          children: [
            _section('Bible'),
            _translationPicker(),
            const SizedBox(height: 32),
            _section('Display'),
            _slider('Verse font size', _settings.verseFontSize, 24, 100, (v) {
              _settings.update((s) => s.verseFontSize = v);
            }),
            _slider('Reference font size', _settings.refFontSize, 14, 60, (v) {
              _settings.update((s) => s.refFontSize = v);
            }),
            _fontPicker(),
            _toggle('Show translation badge', _settings.showTranslation, (v) {
              _settings.update((s) => s.showTranslation = v);
            }),
            _toggle(
                'Show book/chapter/verse reference', _settings.showReference,
                (v) {
              _settings.update((s) => s.showReference = v);
            }),
            _outputBackgroundImageTile(),
            const SizedBox(height: 32),
            _section('Transcript Panel'),
            _toggle('Show live transcript', _settings.showTranscript, (v) {
              _settings.update((s) => s.showTranscript = v);
            }),
            _slider('Transcript opacity', _settings.transcriptOpacity, 0.1, 1.0,
                (v) {
              _settings.update((s) => s.transcriptOpacity = v);
            }),
            const SizedBox(height: 32),
            _section('Offline Bible'),
            _offlineDownloadTile(),
            const SizedBox(height: 32),
            _section('About'),
            _infoTile(
                'Speech recognition', 'Device built-in (free, no API key)'),
            _infoTile('Internet usage', 'Bible download/fetch only'),
            _infoTile(
                'Offline caching', 'Verses cached locally after first load'),
            _infoTile('Supported languages', 'English (US) — speak naturally'),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 3,
            color: Colors.white.withValues(alpha: 0.35),
            fontWeight: FontWeight.w500,
          ),
        ),
      );

  Widget _translationPicker() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _settings.translation,
          dropdownColor: const Color(0xFF1A1A2E),
          style: const TextStyle(color: Colors.white70, fontSize: 15),
          isExpanded: true,
          items: BibleService.availableTranslations
              .map((t) => DropdownMenuItem(
                    value: t['id'],
                    child: Text('${t['name']} (${t['id']!.toUpperCase()})'),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) _settings.update((s) => s.translation = v);
          },
        ),
      ),
    );
  }

  Widget _fontPicker() {
    const fonts = [
      'Georgia',
      'Palatino',
      'Times New Roman',
      'Garamond',
      'System'
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: fonts.contains(_settings.fontFamily)
              ? _settings.fontFamily
              : fonts.first,
          dropdownColor: const Color(0xFF1A1A2E),
          style: const TextStyle(color: Colors.white70, fontSize: 15),
          isExpanded: true,
          hint: const Text('Font family'),
          items: fonts
              .map((f) => DropdownMenuItem(
                    value: f,
                    child: Text(f,
                        style: TextStyle(fontFamily: f == 'System' ? null : f)),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) {
              _settings.update((s) => s.fontFamily = v == 'System' ? '' : v);
            }
          },
        ),
      ),
    );
  }

  Widget _slider(String label, double value, double min, double max,
      ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6), fontSize: 14)),
            Text(value.round().toString(),
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4), fontSize: 13)),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          activeColor: Colors.white.withValues(alpha: 0.6),
          inactiveColor: Colors.white.withValues(alpha: 0.1),
          onChanged: onChanged,
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 14)),
          Switch(
            value: value,
            // ignore: deprecated_member_use
            activeColor: Colors.white,
            activeTrackColor: Colors.white.withValues(alpha: 0.3),
            inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
          Text(value,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _outputBackgroundImageTile() {
    final hasImage = _settings.outputBackgroundImageUrl.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Output background image (second display)',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasImage
                ? _settings.outputBackgroundImageUrl
                : 'No image selected',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton(
                onPressed: _editOutputBackgroundImage,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                ),
                child: const Text('Set image URL'),
              ),
              const SizedBox(width: 10),
              if (hasImage)
                OutlinedButton(
                  onPressed: () {
                    _settings.update((s) => s.outputBackgroundImageUrl = '');
                  },
                  style: OutlinedButton.styleFrom(
                    side:
                        BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: const Text('Clear'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editOutputBackgroundImage() async {
    final controller =
        TextEditingController(text: _settings.outputBackgroundImageUrl);

    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
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
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (value == null) return;

    _settings.update((s) => s.outputBackgroundImageUrl = value);
  }

  Widget _offlineDownloadTile() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Download ${_settings.translation.toUpperCase()} for full offline use',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'One-time internet download. After this, verse display works offline for this translation.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          if (_offlineDownloading) ...[
            LinearProgressIndicator(
              value: _offlineProgress,
              minHeight: 6,
              color: Colors.white.withValues(alpha: 0.65),
              backgroundColor: Colors.white.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 8),
            Text(
              _offlineLabel,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12,
              ),
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _downloadOfflineBible,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                ),
                child: const Text('Download now'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _downloadOfflineBible() async {
    if (_offlineDownloading) return;

    setState(() {
      _offlineDownloading = true;
      _offlineProgress = 0;
      _offlineLabel = 'Starting…';
    });

    try {
      await _bible.preloadEntireTranslation(
        translation: _settings.translation,
        onProgress: (done, total, label) {
          if (!mounted) return;
          final safeTotal = total <= 0 ? 1 : total;
          setState(() {
            _offlineProgress = done / safeTotal;
            _offlineLabel = 'Downloading $label ($done/$total chapters)';
          });
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${_settings.translation.toUpperCase()} Bible downloaded for offline use.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Offline download failed: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _offlineDownloading = false;
          _offlineProgress = 0;
          _offlineLabel = '';
        });
      }
    }
  }
}
