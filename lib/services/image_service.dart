import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'app_storage_service.dart';

/// Manages background image acquisition and local caching.
///
/// Images are always stored in the app's documents folder so the output screen
/// continues to work even if the original URL goes offline.
class ImageService {
  // ── Directory ──────────────────────────────────────────────────────────────

  static Future<Directory> _imagesDir() async {
    return AppStorageService.imagesDirectory();
  }

  // ── Local file picker ──────────────────────────────────────────────────────

  /// Opens the native file picker so the user can choose a local image.
  /// The selected file is copied into the app's images cache and the cached
  /// path is returned.  Returns null if cancelled or unsupported platform.
  static Future<String?> pickLocalImage() async {
    if (kIsWeb) return null; // FilePicker on web returns bytes, not paths

    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
    } catch (_) {
      return null;
    }

    if (result == null || result.files.isEmpty) return null;
    final sourcePath = result.files.single.path;
    if (sourcePath == null) return null;

    final dir = await _imagesDir();
    final ext = p.extension(sourcePath).toLowerCase();
    final dest = File(
      p.join(dir.path, 'bg_${DateTime.now().millisecondsSinceEpoch}$ext'),
    );
    await File(sourcePath).copy(dest.path);
    return dest.path;
  }

  // ── URL download ───────────────────────────────────────────────────────────

  /// Downloads the image at [url], saves it to the app's images cache, and
  /// returns the local path.  Throws on HTTP error or timeout.
  static Future<String> downloadImage(String url) async {
    final response =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode} while downloading image');
    }

    // Determine file extension from the URL path, default to .jpg
    final uri = Uri.parse(url);
    String ext = p.extension(uri.path).toLowerCase();
    if (!{'.jpg', '.jpeg', '.png', '.webp', '.bmp', '.gif'}.contains(ext)) {
      ext = '.jpg';
    }

    final dir = await _imagesDir();
    final dest = File(
      p.join(dir.path, 'bg_${DateTime.now().millisecondsSinceEpoch}$ext'),
    );
    await dest.writeAsBytes(response.bodyBytes);
    return dest.path;
  }

  // ── Cleanup ────────────────────────────────────────────────────────────────

  /// Deletes a previously cached image file.  Safe to call if the file no
  /// longer exists.
  static Future<void> deleteImage(String localPath) async {
    if (localPath.isEmpty) return;
    try {
      final f = File(localPath);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
