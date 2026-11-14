// Native implementation — compiled only on non-Web platforms (see paths.dart),
// so importing dart:io here is safe.
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Whether a real file system is available.
bool get canUseFileSystem => true;

/// Path of the platform temporary directory.
Future<String> tempDirPath() async => (await getTemporaryDirectory()).path;

/// Writes [bytes] into a file named [fileName] inside the temporary
/// directory and returns the full path.
Future<String> writeTempFile(String fileName, Uint8List bytes) async {
  final dir = await getTemporaryDirectory();
  final sep = dir.path.endsWith('/') || dir.path.endsWith(r'\') ? '' : '/';
  final file = File('${dir.path}$sep$fileName');
  await file.writeAsBytes(bytes);
  return file.path;
}

/// Whether the file at [path] exists on disk.
Future<bool> fileExists(String path) => File(path).exists();

/// Size of the file at [path] in bytes, or -1 when it cannot be read.
Future<int> fileSizeBytes(String path) async {
  try {
    return await File(path).length();
  } catch (_) {
    return -1;
  }
}
