import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Keeps user-picked files (bill photos, vehicle photos, papers, documents)
/// inside the app's own documents folder.
///
/// Pickers hand back paths in the app cache or other temporary places that
/// Android can clear at any time, so every attachment is copied here before
/// its path is saved in the database.
class FileStorage {
  FileStorage._();

  static const _uuid = Uuid();

  static const String photosFolder = 'photos';
  static const String papersFolder = 'vehicle_papers';
  static const String documentsFolder = 'general_documents';

  static Future<String> _docsPath() async =>
      (await getApplicationDocumentsDirectory()).path;

  /// Whether [path] is inside the app documents folder.
  static Future<bool> isOwned(String path) async =>
      p.isWithin(await _docsPath(), path);

  /// Copies [sourcePath] into `<appDocs>/<folder>/` under a unique name and
  /// returns the new path. A file already inside app documents is returned
  /// unchanged.
  static Future<String> importFile(String sourcePath, String folder) async {
    final docs = await _docsPath();
    if (p.isWithin(docs, sourcePath)) return sourcePath;

    final ext = p.extension(sourcePath);
    var base = p
        .basenameWithoutExtension(sourcePath)
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (base.length > 40) base = base.substring(0, 40);
    final name =
        '${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4().substring(0, 8)}_$base$ext';

    final dir = Directory(p.join(docs, folder));
    await dir.create(recursive: true);
    final dest = p.join(dir.path, name);
    await File(sourcePath).copy(dest);
    return dest;
  }

  /// Deletes the given files, but only ones inside app documents. Files
  /// elsewhere belong to the user and are never touched. Errors are ignored.
  static Future<void> deleteOwnedFiles(Iterable<String?> paths) async {
    final docs = await _docsPath();
    for (final path in paths) {
      if (path == null || path.isEmpty || !p.isWithin(docs, path)) continue;
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (e) {
        debugPrint('Could not delete $path: $e');
      }
    }
  }
}
