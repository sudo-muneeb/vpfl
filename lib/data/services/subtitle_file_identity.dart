import 'dart:io';

import 'package:path/path.dart' as path;

/// Resolves local subtitle paths for comparison with mpv's external filename.
///
/// mpv can report a filesystem path while a picker or caller supplies a file
/// URI. Resolving links also makes repeat selection of the same file stable.
Future<String?> canonicalSubtitlePath(String location) async {
  final String filePath;
  if (location.startsWith('file:')) {
    final uri = Uri.tryParse(location);
    if (uri == null || uri.scheme != 'file') return null;
    try {
      filePath = uri.toFilePath();
    } on UnsupportedError {
      return null;
    }
  } else if (!location.contains('://')) {
    // A plain path can legitimately contain percent signs. Decode only URIs.
    filePath = location;
  } else {
    return null;
  }
  final file = File(filePath);
  try {
    return await file.resolveSymbolicLinks();
  } on FileSystemException {
    return path.normalize(file.absolute.path);
  }
}
