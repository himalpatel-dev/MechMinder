import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';

/// Zip work for backup and restore. Runs on a background isolate so a large
/// backup (many bill photos and PDFs) doesn't freeze the app, and streams
/// files instead of holding all of them in memory at once.
class BackupArchive {
  BackupArchive._();

  /// Writes a backup zip at [zipPath]: [jsonText] as `backup.json`, plus each
  /// file in [files] (zip entry name -> source path). Missing files are
  /// skipped.
  static Future<void> writeZip(
    String zipPath,
    String jsonText,
    Map<String, String> files,
  ) => Isolate.run(() => _writeZip(zipPath, jsonText, files));

  /// Extracts the backup zip at [zipPath] into [outDir] and returns the text
  /// of its `backup.json`. Throws [FormatException] if it isn't a backup.
  static Future<String> extractZip(String zipPath, String outDir) =>
      Isolate.run(() => _extractZip(zipPath, outDir));
}

Future<void> _writeZip(
  String zipPath,
  String jsonText,
  Map<String, String> files,
) async {
  final encoder = ZipFileEncoder();
  encoder.create(zipPath);
  try {
    final jsonBytes = utf8.encode(jsonText);
    encoder.addArchiveFile(
      ArchiveFile('backup.json', jsonBytes.length, jsonBytes),
    );
    for (final entry in files.entries) {
      final file = File(entry.value);
      if (await file.exists()) {
        await encoder.addFile(file, entry.key);
      }
    }
  } finally {
    await encoder.close();
  }
}

Future<String> _extractZip(String zipPath, String outDir) async {
  final input = InputFileStream(zipPath);
  try {
    final archive = ZipDecoder().decodeBuffer(input);
    final jsonFile = archive.findFile('backup.json');
    if (jsonFile == null) {
      throw const FormatException(
        'Invalid backup: backup.json not found in the zip.',
      );
    }
    final jsonText = utf8.decode(jsonFile.content as List<int>);

    // extractArchiveToDisk skips any entry whose path would end up outside
    // outDir (e.g. "../../databases/x"), so a crafted zip can't overwrite
    // the app's database or settings ("zip slip").
    await extractArchiveToDisk(archive, outDir);
    return jsonText;
  } finally {
    await input.close();
  }
}
