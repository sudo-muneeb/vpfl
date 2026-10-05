import 'dart:io';

import 'package:path/path.dart' as path;

/// Formats users may choose explicitly. MPEG transport streams use `.ts`,
/// which also names TypeScript source, so folder indexing excludes it.
abstract final class MediaFormatPolicy {
  static const Set<String> _declarationSuffixes = {'.d.ts', '.d.mts', '.d.cts'};

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

  static bool isDeclarationFile(String filePath) {
    final name = path.basename(filePath).toLowerCase();
    return _declarationSuffixes.any(name.endsWith);
  }

  /// File type is checked by the scanner before calling this path policy.
  static String automaticScanReason(String filePath) {
    if (isDeclarationFile(filePath)) return 'source-declaration';
    final extension = extensionOf(filePath);
    if (extension == 'ts') return 'ambiguous-ts';
    if (!supportedForAutomaticLibraryScan.contains(extension)) {
      return 'unsupported-extension';
    }
    return 'accepted';
  }

  static bool shouldAutomaticallyIndex(String filePath) =>
      automaticScanReason(filePath) == 'accepted';

  static bool mayScan(String filePath) => shouldAutomaticallyIndex(filePath);

  /// `.mts` is also used by TypeScript modules. Probe packet sync bytes for
  /// automatic discovery; explicit Open file remains available for unusual
  /// transport streams that do not match this short signature.
  static Future<bool> hasTransportStreamSignature(File file) async {
    if (extensionOf(file.path) != 'mts') return true;
    final handle = await file.open();
    try {
      final bytes = await handle.read(389);
      for (final packetSize in [188, 192]) {
        for (final start in [0, 4]) {
          if (start + packetSize * 2 < bytes.length &&
              bytes[start] == 0x47 &&
              bytes[start + packetSize] == 0x47 &&
              bytes[start + packetSize * 2] == 0x47) {
            return true;
          }
        }
      }
      return false;
    } finally {
      await handle.close();
    }
  }

  static bool mayOpenExplicitly(String filePath) =>
      !isDeclarationFile(filePath) &&
      supportedForExplicitOpen.contains(extensionOf(filePath));
}
