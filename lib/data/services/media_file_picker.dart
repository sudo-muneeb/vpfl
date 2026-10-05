import 'package:file_selector/file_selector.dart';

import 'media_format_policy.dart';

const List<String> videoExtensions = MediaFormatPolicy.supportedForExplicitOpen;
const List<String> subtitleExtensions =
    MediaFormatPolicy.supportedSubtitleExtensions;

/// Opens the native file picker and returns the selected video as a file URI.
Future<String?> pickVideoUri() async {
  final XFile? file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(label: 'Video files', extensions: videoExtensions),
      XTypeGroup(label: 'All files'),
    ],
  );
  return file == null ? null : Uri.file(file.path).toString();
}

/// Opens the desktop folder chooser for a library root.
Future<String?> pickLibraryFolder() => getDirectoryPath();

/// Opens the native picker for an external subtitle track.
Future<String?> pickSubtitlePath() async {
  final XFile? file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(label: 'Subtitle files', extensions: subtitleExtensions),
    ],
  );
  return file?.path;
}
