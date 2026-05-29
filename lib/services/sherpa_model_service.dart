import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class SherpaModelInfo {
  final String name;
  final String displayName;
  final String url;
  final String dirName;
  final String encoderFile;
  final String decoderFile;
  final String joinerFile;
  final String tokensFile;

  const SherpaModelInfo({
    required this.name,
    required this.displayName,
    required this.url,
    required this.dirName,
    required this.encoderFile,
    required this.decoderFile,
    required this.joinerFile,
    required this.tokensFile,
  });
}

const kDefaultSherpaModel = SherpaModelInfo(
  name: 'zipformer-en-2023-06-26',
  displayName: 'English Zipformer (~105 MB)',
  url: 'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/'
      'sherpa-onnx-streaming-zipformer-en-2023-06-26.tar.bz2',
  dirName: 'sherpa-onnx-streaming-zipformer-en-2023-06-26',
  encoderFile: 'encoder-epoch-99-avg-1-chunk-16-left-128.int8.onnx',
  decoderFile: 'decoder-epoch-99-avg-1-chunk-16-left-128.int8.onnx',
  joinerFile: 'joiner-epoch-99-avg-1-chunk-16-left-128.int8.onnx',
  tokensFile: 'tokens.txt',
);

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

class SherpaModelService {
  static SherpaModelService? _instance;
  SherpaModelService._();
  static SherpaModelService get instance =>
      _instance ??= SherpaModelService._();

  void _log(String message) {
    stdout.writeln('[SherpaModelService] $message');
  }

  String _formatBytes(int bytes) => '${(bytes / 1e6).toStringAsFixed(1)} MB';

  Future<Directory> get _modelsDir async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'sherpa_models'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  Future<String> modelDir(SherpaModelInfo info) async {
    final base = await _modelsDir;
    return p.join(base.path, info.dirName);
  }

  Future<bool> isDownloaded(SherpaModelInfo info) async {
    final dir = await modelDir(info);
    return File(p.join(dir, info.tokensFile)).existsSync() &&
        File(p.join(dir, info.encoderFile)).existsSync();
  }

  Future<String> encoderPath(SherpaModelInfo info) async =>
      p.join(await modelDir(info), info.encoderFile);
  Future<String> decoderPath(SherpaModelInfo info) async =>
      p.join(await modelDir(info), info.decoderFile);
  Future<String> joinerPath(SherpaModelInfo info) async =>
      p.join(await modelDir(info), info.joinerFile);
  Future<String> tokensPath(SherpaModelInfo info) async =>
      p.join(await modelDir(info), info.tokensFile);

  Stream<ModelDownloadProgress> download(SherpaModelInfo info) async* {
    final base = await _modelsDir;
    final tempDir = await getTemporaryDirectory();
    final tarPath = p.join(tempDir.path, '${info.dirName}.tar.bz2');

    _log('Starting download for ${info.displayName} (${info.name})');
    _log('Model directory: ${base.path}');
    _log('Temporary archive: $tarPath');
    _log('Source URL: ${info.url}');

    try {
      yield const ModelDownloadProgress(
          received: 0, total: 0, status: 'Connecting…');

      _log('Opening HTTP request');
      final request = http.Request('GET', Uri.parse(info.url));
      final response = await request.send();

      _log(
          'HTTP response: ${response.statusCode} ${response.reasonPhrase ?? ''}'
              .trim());
      _log('Response headers: ${response.headers}');

      if (response.statusCode != 200) {
        _log('Download failed before body transfer');
        yield ModelDownloadProgress(
          received: 0,
          total: 0,
          status: 'Download failed',
          error: 'HTTP ${response.statusCode}',
        );
        return;
      }

      final total = response.contentLength ?? 0;
      _log('Content length: ${total > 0 ? _formatBytes(total) : 'unknown'}');
      int received = 0;
      final sink = File(tarPath).openWrite();
      _log('Writing archive to disk');

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          final percent = ((received / total) * 100).toStringAsFixed(0);
          _log(
              'Downloaded $percent% (${_formatBytes(received)} / ${_formatBytes(total)})');
        } else {
          _log('Downloaded ${_formatBytes(received)}');
        }
        yield ModelDownloadProgress(
          received: received,
          total: total,
          status: 'Downloading…',
        );
      }
      await sink.flush();
      await sink.close();

      _log(
          'Archive download complete: ${_formatBytes(received)} saved to $tarPath');

      yield ModelDownloadProgress(
        received: received,
        total: total,
        status: 'Extracting…',
      );

      _log('Extracting archive into ${base.path}');
      await _extractTarBz2(tarPath, base.path);
      _log('Extraction complete');

      final tarFile = File(tarPath);
      if (tarFile.existsSync()) {
        _log('Deleting temporary archive');
        await tarFile.delete();
      }

      yield ModelDownloadProgress(
        received: received,
        total: total,
        status: 'Ready',
        done: true,
      );
      _log('Model download finished successfully');
    } catch (e, st) {
      _log('Download failed with exception: $e');
      _log(st.toString());
      final tarFile = File(tarPath);
      if (tarFile.existsSync()) {
        try {
          _log('Cleaning up temporary archive after failure');
          await tarFile.delete();
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

  Future<void> _extractTarBz2(String tarPath, String destDir) async {
    await Future(() {
      final bzipDecoder = BZip2Decoder();
      final tarDecoder = TarDecoder();
      final tarBytes = bzipDecoder.decodeBytes(File(tarPath).readAsBytesSync());
      final archive = tarDecoder.decodeBytes(tarBytes);
      _log('Archive contains ${archive.length} entries');
      for (final file in archive) {
        final outPath = p.join(destDir, file.name);
        _log('Extracting ${file.name} -> $outPath');
        if (file.isFile) {
          final outFile = File(outPath);
          outFile.parent.createSync(recursive: true);
          outFile.writeAsBytesSync(file.content as List<int>);
        } else {
          Directory(outPath).createSync(recursive: true);
        }
      }
    });
  }

  Future<void> deleteModel(SherpaModelInfo info) async {
    final dir = Directory(await modelDir(info));
    if (dir.existsSync()) await dir.delete(recursive: true);
  }
}
