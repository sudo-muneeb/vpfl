import 'dart:io';

/// Gives local paths and file URIs the same identity throughout playback.
String canonicalMediaUri(String source) {
  final parsed = Uri.tryParse(source);
  if (parsed != null && parsed.scheme == 'file') {
    return Uri.file(parsed.toFilePath()).normalizePath().toString();
  }
  if (parsed == null || parsed.scheme.isEmpty) {
    return Uri.file(File(source).absolute.path).normalizePath().toString();
  }
  return source;
}
