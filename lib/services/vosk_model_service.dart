import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'app_storage_service.dart';

// ── Model catalogue ────────────────────────────────────────────────────────
//
// Add entries here if you want to offer multiple languages.
// The 'small' English model is ~40 MB and works well for spoken Bible refs.

class VoskModelInfo {
  final String name;
  final String url;
  final String displayName;
  final String dirName;

  const VoskModelInfo({
    required this.name,
    required this.url,
    required this.displayName,
    required this.dirName,
  });
}

const kVoskModels = [
  VoskModelInfo(
    name: 'en-us-small',
    displayName: 'English (small, ~40 MB)',
    url: 'https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip',
    dirName: 'vosk-model-small-en-us-0.15',
  ),
  VoskModelInfo(
    name: 'en-us-large',
    displayName: 'English (large, ~1.8 GB)',
    url: 'https://alphacephei.com/vosk/models/vosk-model-en-us-0.22.zip',
    dirName: 'vosk-model-en-us-0.22',
  ),
];

final kDefaultModel = kVoskModels[1];

// ── Download progress ──────────────────────────────────────────────────────

class ModelDownloadProgress {
  final int received;
  final int total;
  final String status;
  final bool done;
  final String? error;

  const ModelDownloadProgress({
    required this.received,
    required this.total,
    required this.status,
    this.done = false,
    this.error,
  });

  double get fraction => total > 0 ? received / total : 0;
  String get percent => '${(fraction * 100).toStringAsFixed(0)}%';
  String get mbReceived => '${(received / 1e6).toStringAsFixed(1)} MB';
  String get mbTotal => '${(total / 1e6).toStringAsFixed(1)} MB';
}

// ── Service ────────────────────────────────────────────────────────────────

class VoskModelService {
  static VoskModelService? _instance;
  VoskModelService._();
  static VoskModelService get instance => _instance ??= VoskModelService._();

  // ── Paths ──────────────────────────────────────────────────────────────────

  Future<Directory> get _modelsDir async {
    return AppStorageService.modelsDirectory();
  }

  Future<String> modelPath(VoskModelInfo info) async {
    final base = await _modelsDir;
    return p.join(base.path, info.dirName);
  }

  // ── Status ─────────────────────────────────────────────────────────────────

  Future<bool> isDownloaded(VoskModelInfo info) async {
    final path = await modelPath(info);
    // The presence of 'am/final.mdl' indicates a valid extracted model.
    return File(p.join(path, 'am', 'final.mdl')).existsSync();
  }

  // ── Download + extract ─────────────────────────────────────────────────────

  /// Streams download and extraction progress.
  /// Completes (done = true) when the model is ready, or emits an error field.
  Stream<ModelDownloadProgress> download(VoskModelInfo info) async* {
    final base = await _modelsDir;
    final zipPath = p.join(base.path, '${info.dirName}.zip');

    try {
      // ── Download ──────────────────────────────────────────────────────────
      yield const ModelDownloadProgress(
          received: 0, total: 0, status: 'Connecting…');

      final request = http.Request('GET', Uri.parse(info.url));
      final response = await request.send();

      if (response.statusCode != 200) {
        yield ModelDownloadProgress(
          received: 0,
          total: 0,
          status: 'Download failed',
          error: 'HTTP ${response.statusCode}',
        );
        return;
      }

      final total = response.contentLength ?? 0;
      int received = 0;
      final sink = File(zipPath).openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        yield ModelDownloadProgress(
          received: received,
          total: total,
          status: 'Downloading…',
        );
      }
      await sink.flush();
      await sink.close();

      // ── Extract ───────────────────────────────────────────────────────────
      yield ModelDownloadProgress(
        received: received,
        total: total,
        status: 'Extracting…',
      );

      await _extractZip(zipPath, base.path);

      // ── Clean up zip ──────────────────────────────────────────────────────
      final zipFile = File(zipPath);
      if (zipFile.existsSync()) await zipFile.delete();

      yield ModelDownloadProgress(
        received: received,
        total: total,
        status: 'Ready',
        done: true,
      );
    } catch (e) {
      // Clean up partial zip
      final zipFile = File(zipPath);
      if (zipFile.existsSync()) {
        try {
          await zipFile.delete();
        } catch (_) {}
      }
      yield ModelDownloadProgress(
        received: 0,
        total: 0,
        status: 'Error',
        error: e.toString(),
      );
    }
  }

  Future<void> _extractZip(String zipPath, String destDir) async {
    await Future(() {
      final inputStream = InputFileStream(zipPath);
      final archive = ZipDecoder().decodeStream(inputStream);
      for (final file in archive) {
        final outPath = p.join(destDir, file.name);
        if (file.isFile) {
          final outFile = File(outPath);
          outFile.parent.createSync(recursive: true);
          outFile.writeAsBytesSync(file.content as List<int>);
        } else {
          Directory(outPath).createSync(recursive: true);
        }
      }
      inputStream.closeSync();
    });
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> deleteModel(VoskModelInfo info) async {
    final path = await modelPath(info);
    final dir = Directory(path);
    if (dir.existsSync()) await dir.delete(recursive: true);
  }
}
