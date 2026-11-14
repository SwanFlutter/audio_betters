// Web implementation — compiled only on Web (see paths.dart). Browsers have no
// accessible file system, so these helpers degrade gracefully.
import 'dart:typed_data';

/// Browsers cannot write recordings to a real file path.
bool get canUseFileSystem => false;

/// Not available on Web — never call this without checking [canUseFileSystem]
/// or `kIsWeb` first.
Future<String> tempDirPath() async {
  throw UnsupportedError('The browser has no temporary directory.');
}

/// Browsers keep blobs in memory; the "path" is just the requested name until
/// the recorder finalizes and hands back a `blob:` URL.
Future<String> writeTempFile(String fileName, Uint8List bytes) async =>
    fileName;

/// There is no file system to check — assume the in-memory blob/URL is valid.
Future<bool> fileExists(String path) async => true;

/// File size is unknown in the browser.
Future<int> fileSizeBytes(String path) async => -1;
