import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppStorageService {
  static const String rootFolderName = 'Bible Screen';
  static const String songDatabaseFolder = 'song_database';
  static const String imagesFolder = 'images';
  static const String modelsFolder = 'speech_models';

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

    return newDir;
  }
}
