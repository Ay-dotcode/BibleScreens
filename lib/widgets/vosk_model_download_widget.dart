import 'dart:async';

import 'package:flutter/material.dart';

import '../services/vosk_model_service.dart';

/// Drop-in overlay shown in the mic controls area when the Vosk model
/// hasn't been downloaded yet.
///
/// Usage in HomeScreen — listen for 'model_not_downloaded' on errorStream
/// and set a flag to show this widget in place of the normal mic controls.
///
/// Example:
///   _errorSub = _speech.errorStream.listen((e) {
///     if (e == 'model_not_downloaded') {
///       setState(() => _needsModelDownload = true);
///     } else {
///       _showError(e);
///     }
///   });
///
/// Then in _buildMicControls / wherever:
///   if (_needsModelDownload)
///     return VoskModelDownloadWidget(
///       onReady: () => setState(() => _needsModelDownload = false),
///     );

class VoskModelDownloadWidget extends StatefulWidget {
  /// Called when the model is downloaded and ready — re-init the service.
  final VoidCallback onReady;

  const VoskModelDownloadWidget({super.key, required this.onReady});

  @override
  State<VoskModelDownloadWidget> createState() =>
      _VoskModelDownloadWidgetState();
}

class _VoskModelDownloadWidgetState extends State<VoskModelDownloadWidget> {
  final _svc = VoskModelService.instance;
  ModelDownloadProgress? _progress;
  StreamSubscription<ModelDownloadProgress>? _sub;
  bool _downloading = false;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _startDownload() {
    setState(() => _downloading = true);
    _sub = _svc.download(kDefaultModel).listen(
      (p) {
        if (!mounted) return;
        setState(() => _progress = p);
        if (p.done) {
          _sub?.cancel();
          widget.onReady();
        }
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _downloading = false;
          _progress = ModelDownloadProgress(
            received: 0,
            total: 0,
            status: 'Error',
            error: e.toString(),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = _progress;

    // Error state
    if (p?.error != null) {
      return _bar(theme, children: [
        Icon(Icons.error_outline_rounded, size: 16, color: Colors.red.shade400),
        const SizedBox(width: 8),
        Expanded(
          child: Text('Download failed: ${p!.error}',
              style: TextStyle(fontSize: 12, color: Colors.red.shade400)),
        ),
        TextButton(onPressed: _startDownload, child: const Text('Retry')),
      ]);
    }

    // Downloading / extracting
    if (_downloading && p != null && !p.done) {
      final isExtracting = p.status == 'Extracting…';
      return _bar(theme, children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
              strokeWidth: 2,
              value:
                  isExtracting ? null : (p.fraction > 0 ? p.fraction : null)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isExtracting
                    ? 'Extracting model…'
                    : 'Downloading Vosk model  ${p.mbReceived} / ${p.mbTotal}',
                style: TextStyle(
                    fontSize: 12, color: theme.textTheme.bodySmall?.color),
              ),
              if (!isExtracting && p.total > 0) ...[
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: p.fraction,
                    minHeight: 3,
                  ),
                ),
              ],
            ],
          ),
        ),
        Text(isExtracting ? '' : p.percent,
            style: TextStyle(
                fontSize: 11,
                color: theme.textTheme.bodySmall?.color,
                fontFeatures: const [FontFeature.tabularFigures()])),
      ]);
    }

    // Idle — not yet started
    return _bar(theme, children: [
      Icon(Icons.download_rounded,
          size: 16, color: theme.textTheme.bodySmall?.color),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          'Offline speech recognition requires a one-time model download (~1.8 GB).',
          style:
              TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
        ),
      ),
      const SizedBox(width: 8),
      FilledButton.icon(
        onPressed: _startDownload,
        icon: const Icon(Icons.download_rounded, size: 14),
        label: const Text('Download', style: TextStyle(fontSize: 12)),
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    ]);
  }

  Widget _bar(ThemeData theme, {required List<Widget> children}) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      color: theme.cardColor,
      child: Row(children: children),
    );
  }
}
