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
  encoderFile: 'encoder-epoch-99-avg-1.int8.onnx',
  decoderFile: 'decoder-epoch-99-avg-1.int8.onnx',
  joinerFile: 'joiner-epoch-99-avg-1.int8.onnx',
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
    final tarPath = p.join(base.path, '${info.dirName}.tar.bz2');

    try {
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
      final sink = File(tarPath).openWrite();

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

      yield ModelDownloadProgress(
        received: received,
        total: total,
        status: 'Extracting…',
      );

      await _extractTarBz2(tarPath, base.path);

      final tarFile = File(tarPath);
      if (tarFile.existsSync()) await tarFile.delete();

      yield ModelDownloadProgress(
        received: received,
        total: total,
        status: 'Ready',
        done: true,
      );
    } catch (e) {
      final tarFile = File(tarPath);
      if (tarFile.existsSync()) {
        try {
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
      final inputStream = InputFileStream(tarPath);
      final bzipDecoder = BZip2Decoder();
      final tarDecoder = TarDecoder();
      final tarBytes = bzipDecoder.decodeBytes(inputStream.toUint8List());
      final archive = tarDecoder.decodeBytes(tarBytes);
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
    });
  }

  Future<void> deleteModel(SherpaModelInfo info) async {
    final dir = Directory(await modelDir(info));
    if (dir.existsSync()) await dir.delete(recursive: true);
  }
}
