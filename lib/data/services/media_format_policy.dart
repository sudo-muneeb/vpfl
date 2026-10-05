import 'package:path/path.dart' as path;

/// Formats users may choose explicitly. MPEG transport streams use `.ts`,
/// which also names TypeScript source, so folder indexing excludes it.
abstract final class MediaFormatPolicy {
  static const List<String> supportedForExplicitOpen = [
    '3g2',
    '3gp',
    'asf',
    'avi',
    'flv',
    'm2ts',
    'm4v',
    'mkv',
    'mov',
    'mp4',
    'mpeg',
    'mpg',
    'mts',
    'mxf',
    'ogv',
    'ts',
    'vob',
    'webm',
    'wmv',
  ];

  static const Set<String> supportedForAutomaticLibraryScan = {
    '3g2',
    '3gp',
    'asf',
    'avi',
    'flv',
    'm2ts',
    'm4v',
    'mkv',
    'mov',
    'mp4',
    'mpeg',
    'mpg',
    'mts',
    'mxf',
    'ogv',
    'vob',
    'webm',
    'wmv',
  };

  static const List<String> supportedSubtitleExtensions = [
    'srt',
    'ass',
    'ssa',
    'vtt',
  ];

  static String extensionOf(String filePath) =>
      path.extension(filePath).replaceFirst('.', '').toLowerCase();

  static bool mayScan(String filePath) =>
      supportedForAutomaticLibraryScan.contains(extensionOf(filePath));

  static bool mayOpenExplicitly(String filePath) =>
      supportedForExplicitOpen.contains(extensionOf(filePath));
}
