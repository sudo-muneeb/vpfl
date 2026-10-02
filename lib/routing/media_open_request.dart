import 'dart:io';

/// The local media source requested when launching VPFL.
class MediaOpenRequest {
  const MediaOpenRequest({required this.uri});

  /// Creates a media request from the supported command-line arguments.
  ///
  /// VPFL accepts no arguments or one local file path. Relative paths are
  /// resolved against the current working directory. A quoted home-relative
  /// path is expanded as a convenience for shells that preserve the tilde.
  static MediaOpenRequest? parseArguments(
    List<String> arguments, {
    String? homeDirectory,
    String? currentDirectory,
  }) {
    if (arguments.isEmpty) {
      return null;
    }
    if (arguments.length != 1) {
      throw const FormatException('VPFL accepts one local media file path.');
    }

    final String input = arguments.single;
    if (input.isEmpty) {
      throw const FormatException('The media file path cannot be empty.');
    }

    String resolvedInput = input;
    if (input == '~' || input.startsWith('~/')) {
      final String? home = homeDirectory ?? Platform.environment['HOME'];
      if (home == null || home.isEmpty) {
        throw const FormatException('Could not resolve the home directory.');
      }
      resolvedInput = input == '~' ? home : '$home${input.substring(1)}';
    }

    final File file = File(resolvedInput);
    final String absolutePath = file.isAbsolute
        ? file.path
        : '${currentDirectory ?? Directory.current.path}/$resolvedInput';
    return MediaOpenRequest(uri: Uri.file(absolutePath).toString());
  }

  /// A canonical file URI suitable for `media_kit`'s `Media` source.
  final String uri;
}
