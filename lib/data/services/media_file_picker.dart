import 'package:file_selector/file_selector.dart';

const List<String> videoExtensions = [
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
  'ogv',
  'ts',
  'vob',
  'webm',
  'wmv',
];

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
