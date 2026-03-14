import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../services/bible_service.dart';
import '../services/image_service.dart';
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

  bool _imageDownloading = false;

  @override
  void initState() {
    super.initState();
    _bible.init();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _settings,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text(
            'Settings',
            style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.w300),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          children: [
            _section('Appearance', theme),
            _themePicker(theme),
            const SizedBox(height: 24),
            _section('Bible', theme),
            _translationPicker(theme),
            const SizedBox(height: 24),
            _section('Output Display', theme),
            _slider('Verse font size', _settings.verseFontSize, 24, 100,
                (v) => _settings.update((s) => s.verseFontSize = v), theme),
            _slider('Reference font size', _settings.refFontSize, 14, 60,
                (v) => _settings.update((s) => s.refFontSize = v), theme),
            _fontPicker(theme),
            _toggle('Show translation badge', _settings.showTranslation,
                (v) => _settings.update((s) => s.showTranslation = v), theme),
            _toggle('Show book/chapter/verse label', _settings.showReference,
                (v) => _settings.update((s) => s.showReference = v), theme),
            const SizedBox(height: 12),
            _transitionPicker(theme),
            const SizedBox(height: 12),
            _backgroundImageTile(theme),
            const SizedBox(height: 24),
            _section('Transcript Panel', theme),
            _toggle('Show live transcript', _settings.showTranscript,
                (v) => _settings.update((s) => s.showTranscript = v), theme),
            _slider('Transcript opacity', _settings.transcriptOpacity, 0.1, 1.0,
                (v) => _settings.update((s) => s.transcriptOpacity = v), theme),
            const SizedBox(height: 24),
            _section('Offline Bible', theme),
            _offlineDownloadTile(theme),
            const SizedBox(height: 24),
            _section('About', theme),
            _infoTile('Speech backend', 'Deepgram nova-3 (WebSocket)', theme),
            _infoTile('Internet usage', 'Bible fetch + image download', theme),
            _infoTile(
                'Offline caching', 'Verses cached after first load', theme),
            _infoTile('Supported languages', 'English (US)', theme),
          ],
        ),
      ),
    );
  }

  // ── Section heading ────────────────────────────────────────────────────────

  Widget _section(String title, ThemeData theme) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 3,
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  // ── Theme picker ───────────────────────────────────────────────────────────

  Widget _themePicker(ThemeData theme) {
    return _card(
      theme,
      child: Row(
        children: [
          Expanded(
            child: Text('App theme',
                style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color, fontSize: 14)),
          ),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_rounded),
                  label: Text('Auto')),
              ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_rounded),
                  label: Text('Light')),
              ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_rounded),
                  label: Text('Dark')),
            ],
            selected: {_settings.themeMode},
            onSelectionChanged: (s) =>
                _settings.update((st) => st.themeMode = s.first),
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  // ── Transition picker ──────────────────────────────────────────────────────

  Widget _transitionPicker(ThemeData theme) {
    const opts = [
      ('crossfade', 'Crossfade', Icons.compare_rounded),
      ('slideUp', 'Slide up', Icons.arrow_upward_rounded),
      ('fadeBlack', 'Fade black', Icons.brightness_2_rounded),
    ];
    return _card(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Verse transition',
              style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color, fontSize: 14)),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: opts
                .map((o) => ButtonSegment(
                      value: o.$1,
                      icon: Icon(o.$3, size: 16),
                      label: Text(o.$2),
                    ))
                .toList(),
            selected: {_settings.outputTransition},
            onSelectionChanged: (s) =>
                _settings.update((st) => st.outputTransition = s.first),
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
          ),
        ],
      ),
    );
  }

  // ── Background image ───────────────────────────────────────────────────────

  Widget _backgroundImageTile(ThemeData theme) {
    final hasLocal = _settings.localBackgroundImagePath.isNotEmpty;
    final hasUrl = _settings.outputBackgroundImageUrl.isNotEmpty;
    final hasAny = hasLocal || hasUrl;

    return _card(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Output background image',
              style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),

          // Preview thumbnail (local only)
          if (!kIsWeb && hasLocal) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.file(
                File(_settings.localBackgroundImagePath),
                height: 90,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],

          if (!hasAny) ...[
            const SizedBox(height: 4),
            Text('No image set',
                style: TextStyle(
                    color: theme.textTheme.bodySmall?.color, fontSize: 12)),
          ] else ...[
            const SizedBox(height: 4),
            Text(
                hasLocal
                    ? _settings.localBackgroundImagePath
                    : _settings.outputBackgroundImageUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: theme.textTheme.bodySmall?.color, fontSize: 11)),
          ],

          const SizedBox(height: 12),

          if (_imageDownloading)
            const LinearProgressIndicator()
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!kIsWeb)
                  OutlinedButton.icon(
                    onPressed: _pickLocalImage,
                    icon: const Icon(Icons.folder_open_rounded, size: 16),
                    label: const Text('Pick from computer'),
                  ),
                OutlinedButton.icon(
                  onPressed: _enterImageUrl,
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Download from URL'),
                ),
                if (hasAny)
                  OutlinedButton.icon(
                    onPressed: _clearImage,
                    icon: const Icon(Icons.clear_rounded, size: 16),
                    label: const Text('Clear'),
                    style:
                        OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _pickLocalImage() async {
    setState(() => _imageDownloading = true);
    try {
      final path = await ImageService.pickLocalImage();
      if (path != null && mounted) {
        // Delete old cached image if one exists
        await ImageService.deleteImage(_settings.localBackgroundImagePath);
        _settings.update((s) {
          s.localBackgroundImagePath = path;
          s.outputBackgroundImageUrl = '';
        });
      }
    } catch (e) {
      if (mounted) _showSnack('Could not pick image: $e');
    } finally {
      if (mounted) setState(() => _imageDownloading = false);
    }
  }

  Future<void> _enterImageUrl() async {
    final ctrl = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter image URL'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'https://example.com/bg.jpg',
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Download'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (url == null || url.isEmpty || !mounted) return;

    setState(() => _imageDownloading = true);
    try {
      final localPath = await ImageService.downloadImage(url);
      await ImageService.deleteImage(_settings.localBackgroundImagePath);
      _settings.update((s) {
        s.localBackgroundImagePath = localPath;
        s.outputBackgroundImageUrl = url;
      });
      if (mounted) _showSnack('Image downloaded and cached locally.');
    } catch (e) {
      if (mounted) _showSnack('Download failed: $e');
    } finally {
      if (mounted) setState(() => _imageDownloading = false);
    }
  }

  Future<void> _clearImage() async {
    await ImageService.deleteImage(_settings.localBackgroundImagePath);
    _settings.update((s) {
      s.localBackgroundImagePath = '';
      s.outputBackgroundImageUrl = '';
    });
  }

  // ── Translation picker ─────────────────────────────────────────────────────

  Widget _translationPicker(ThemeData theme) {
    return _card(
      theme,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _settings.translation,
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

  // ── Font picker ────────────────────────────────────────────────────────────

  Widget _fontPicker(ThemeData theme) {
    const fonts = [
      'Georgia',
      'Palatino',
      'Times New Roman',
      'Garamond',
      'System'
    ];
    return _card(
      theme,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: fonts.contains(_settings.fontFamily)
              ? _settings.fontFamily
              : fonts.first,
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

  // ── Slider ─────────────────────────────────────────────────────────────────

  Widget _slider(String label, double value, double min, double max,
      ValueChanged<double> onChanged, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color, fontSize: 14)),
            Text('${value.round()}',
                style: TextStyle(
                    color: theme.textTheme.bodySmall?.color, fontSize: 13)),
          ],
        ),
        Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged),
        const SizedBox(height: 4),
      ],
    );
  }

  // ── Toggle ─────────────────────────────────────────────────────────────────

  Widget _toggle(
      String label, bool value, ValueChanged<bool> onChanged, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color, fontSize: 14)),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  // ── Info tile ──────────────────────────────────────────────────────────────

  Widget _infoTile(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: theme.textTheme.bodySmall?.color, fontSize: 13)),
          Text(value,
              style: TextStyle(
                  color:
                      theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                  fontSize: 13)),
        ],
      ),
    );
  }

  // ── Card wrapper ───────────────────────────────────────────────────────────

  Widget _card(ThemeData theme, {required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor),
      ),
      child: child,
    );
  }

  // ── Offline download ───────────────────────────────────────────────────────

  Widget _offlineDownloadTile(ThemeData theme) {
    return _card(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              'Download ${_settings.translation.toUpperCase()} for offline use',
              style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(
              'Downloads all chapters once so verse display works without internet.',
              style: TextStyle(
                  color: theme.textTheme.bodySmall?.color, fontSize: 12)),
          const SizedBox(height: 12),
          if (_offlineDownloading) ...[
            LinearProgressIndicator(value: _offlineProgress),
            const SizedBox(height: 6),
            Text(_offlineLabel,
                style: TextStyle(
                    color: theme.textTheme.bodySmall?.color, fontSize: 12)),
          ] else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _downloadOfflineBible,
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
            _offlineLabel = 'Downloading $label ($done/$total)';
          });
        },
      );
      if (mounted) {
        _showSnack(
            '${_settings.translation.toUpperCase()} downloaded for offline use.');
      }
    } catch (e) {
      if (mounted) _showSnack('Download failed: $e');
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

  // ── Utilities ──────────────────────────────────────────────────────────────

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
