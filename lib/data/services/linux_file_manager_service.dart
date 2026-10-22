import 'dart:async';
import 'dart:io';

import 'package:vpfl_desktop_linux/vpfl_desktop_linux.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the video's immediate parent in the preferred Linux file manager.
class LinuxFileManagerService {
  const LinuxFileManagerService({
    this.showFolder = _showFolder,
    this.launchDirectory = launchUrl,
  });

  final Future<bool> Function(Uri) showFolder;
  final Future<bool> Function(Uri) launchDirectory;

  static Future<bool> _showFolder(Uri uri) =>
      const VpflDesktopLinux().showFolder(uri);

  Future<void> showContainingFolder(String filePath) async {
    final file = File(filePath).absolute;
    final directory = file.parent;
    if (!await directory.exists().timeout(const Duration(seconds: 5))) {
      throw FileSystemException(
        'Containing folder does not exist',
        directory.path,
      );
    }
    final folderUri = Uri.directory(directory.path);
    Object? fileManagerError;
    try {
      if (await showFolder(folderUri).timeout(const Duration(seconds: 5))) {
        return;
      }
    } on Object catch (error) {
      fileManagerError = error;
    }
    try {
      if (await launchDirectory(folderUri)
          .timeout(const Duration(seconds: 5))) {
        return;
      }
    } on Object catch (error) {
      throw FileSystemException(
        'Could not open the containing folder: $error'
        '${fileManagerError == null ? '' : ' (FileManager1 failed: $fileManagerError)'}',
        directory.path,
      );
    }
    throw FileSystemException(
      'No file manager accepted the containing folder'
      '${fileManagerError == null ? '' : ' (FileManager1 failed: $fileManagerError)'}',
      directory.path,
    );
  }
}
