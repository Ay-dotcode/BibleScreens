import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppStorageService {
  static const String rootFolderName = 'Bible Screen';
  static const String songDatabaseFolder = 'song_database';
  static const String imagesFolder = 'images';
  static const String modelsFolder = 'vosk_models';

  static Future<Directory> get rootDirectory async {
    final docs = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(docs.path, rootFolderName));
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    return root;
  }

  static Future<Directory> subDirectory(String name) async {
    final root = await rootDirectory;
    final dir = Directory(p.join(root.path, name));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<Directory> songDatabaseDirectory() async {
    final newDir = await subDirectory(songDatabaseFolder);
    if (await newDir.exists() && newDir.listSync().isNotEmpty) return newDir;

    final docs = await getApplicationDocumentsDirectory();
    final legacyFolder = ['easy', 'worship', 'dbs'].join('_');
    final legacyDir = Directory(p.join(docs.path, legacyFolder));
    if (await legacyDir.exists()) {
      try {
        await legacyDir.rename(newDir.path);
      } catch (_) {
        for (final entity in legacyDir.listSync()) {
          if (entity is File) {
            final target = File(p.join(newDir.path, p.basename(entity.path)));
            if (!target.existsSync()) {
              await entity.copy(target.path);
            }
          }
        }
      }
    }

    return newDir;
  }

  static Future<Directory> imagesDirectory() async {
    final newDir = await subDirectory(imagesFolder);
    if (await newDir.exists() && newDir.listSync().isNotEmpty) return newDir;

    final docs = await getApplicationDocumentsDirectory();
    final legacyDir = Directory(p.join(docs.path, 'bible_screens', 'images'));
    if (await legacyDir.exists()) {
      for (final entity in legacyDir.listSync()) {
        if (entity is File) {
          final target = File(p.join(newDir.path, p.basename(entity.path)));
          if (!target.existsSync()) {
            await entity.copy(target.path);
          }
        }
      }
    }

    return newDir;
  }

  static Future<Directory> modelsDirectory() async {
    final newDir = await subDirectory(modelsFolder);
    if (await newDir.exists() && newDir.listSync().isNotEmpty) return newDir;

    final docs = await getApplicationDocumentsDirectory();
    final legacyDir = Directory(p.join(docs.path, 'vosk_models'));
    if (await legacyDir.exists()) {
      try {
        await legacyDir.rename(newDir.path);
      } catch (_) {
        for (final entity in legacyDir.listSync()) {
          final name = p.basename(entity.path);
          if (entity is File) {
            final target = File(p.join(newDir.path, name));
            if (!target.existsSync()) {
              await entity.copy(target.path);
            }
          } else if (entity is Directory) {
            final target = Directory(p.join(newDir.path, name));
            await _copyDirectory(entity, target);
          }
        }
      }
    }

    return newDir;
  }

  static Future<void> _copyDirectory(Directory source, Directory target) async {
    if (!await target.exists()) {
      await target.create(recursive: true);
    }

    await for (final entity in source.list(recursive: false)) {
      final name = p.basename(entity.path);
      if (entity is File) {
        final file = File(p.join(target.path, name));
        if (!await file.exists()) {
          await entity.copy(file.path);
        }
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(p.join(target.path, name)));
      }
    }
  }
}
