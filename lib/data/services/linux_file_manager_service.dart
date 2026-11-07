import 'dart:async';
import 'dart:io';

import 'package:vpfl_desktop_linux/vpfl_desktop_linux.dart';
import 'package:url_launcher/url_launcher.dart';

/// Selects a video in the Linux file manager, or opens its immediate parent.
class LinuxFileManagerService {
  const LinuxFileManagerService({
    this.showItem = _showItem,
    this.showFolder = _showFolder,
    this.launchDirectory = launchUrl,
  });

  final Future<bool> Function(Uri) showItem;
  final Future<bool> Function(Uri) showFolder;
  final Future<bool> Function(Uri) launchDirectory;

  static Future<bool> _showItem(Uri uri) =>
      const VpflDesktopLinux().showItem(uri);

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
    if (await file.exists().timeout(const Duration(seconds: 5))) {
      try {
        if (await showItem(Uri.file(file.path))
            .timeout(const Duration(seconds: 5))) {
          return;
        }
      } on Object {
        // A file manager without ShowItems can still open the parent folder.
      }
    }
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
