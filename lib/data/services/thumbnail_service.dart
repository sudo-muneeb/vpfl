import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// Resolves video artwork in the order set by the product scope: a valid
/// Freedesktop thumbnail, then a frame VPFL captured earlier, then nothing
/// (the caller shows a placeholder). It never decodes video itself.
class ThumbnailService {
  ThumbnailService({String? cacheHome})
    : _cacheHome = cacheHome ?? _defaultCacheHome();

  /// Freedesktop size directories, largest useful first for card artwork.
  static const List<String> _freedesktopSizes = ['large', 'x-large', 'normal'];
  static const List<int> _pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];

  final String _cacheHome;
  final StreamController<String> _saved = StreamController<String>.broadcast();

  /// Emits the normalized path of a media file each time VPFL stores a frame.
  Stream<String> get savedFrames => _saved.stream;

  Future<void> close() => _saved.close();

  /// Returns the thumbnail file for [path], or null when none is valid.
  Future<File?> resolve(String path) async {
    final _Identity? identity = await _identityOf(path);
    if (identity == null) return null;

    final String thumbRoot = p.join(_cacheHome, 'thumbnails');
    for (final String size in _freedesktopSizes) {
      final File candidate = File(
        p.join(thumbRoot, size, '${identity.digest}.png'),
      );
      if (await _isValidFreedesktop(candidate, identity)) return candidate;
    }

    final File ownFrame = _ownFrameFile(identity);
    return await ownFrame.exists() ? ownFrame : null;
  }

  /// Stores [png] as the VPFL thumbnail for [path]. The file name carries the
  /// media's modification time, so an edited video never reuses an old frame.
  Future<void> captureFrame(String path, Uint8List png) async {
    final _Identity? identity = await _identityOf(path);
    if (identity == null) return;

    final File target = _ownFrameFile(identity);
    await target.parent.create(recursive: true);
    // Write beside the target and rename, so readers never see a partial PNG.
    final File temporary = File('${target.path}.tmp');
    await temporary.writeAsBytes(png, flush: true);
    await temporary.rename(target.path);
    _saved.add(identity.key);
  }

  /// The key used by [savedFrames] and by callers that watch a path.
  static String keyFor(String path) => p.normalize(p.absolute(path));

  File _ownFrameFile(_Identity identity) => File(
    p.join(
      _cacheHome,
      'vpfl',
      'thumbnails',
      '${identity.digest}-'
          '${identity.modifiedSeconds}.png',
    ),
  );

  static Future<_Identity?> _identityOf(String path) async {
    final String key = keyFor(path);
    final FileStat stat;
    try {
      stat = await FileStat.stat(key);
    } on FileSystemException {
      return null;
    }
    if (stat.type != FileSystemEntityType.file) return null;
    // Freedesktop expects the canonical file URI, the same form used by
    // playback history, so both caches agree on the digest.
    final String uri = Uri.file(key).normalizePath().toString();
    return _Identity(
      key: key,
      uri: uri,
      digest: md5.convert(utf8.encode(uri)).toString(),
      modifiedSeconds: stat.modified.millisecondsSinceEpoch ~/ 1000,
    );
  }

  /// Checks the PNG's `Thumb::MTime` (and `Thumb::URI` when present) against
  /// the media file, as the Freedesktop thumbnail specification requires.
  static Future<bool> _isValidFreedesktop(File file, _Identity identity) async {
    if (!await file.exists()) return false;
    final Map<String, String> text;
    try {
      text = _readPngText(await file.readAsBytes());
    } on FileSystemException {
      return false;
    }
    if (text['Thumb::MTime'] != '${identity.modifiedSeconds}') return false;
    final String? storedUri = text['Thumb::URI'];
    return storedUri == null || storedUri == identity.uri;
  }

  /// Reads the `tEXt` chunks that precede the image data.
  static Map<String, String> _readPngText(Uint8List bytes) {
    final Map<String, String> text = {};
    if (bytes.length < 8) return text;
    for (var i = 0; i < _pngSignature.length; i++) {
      if (bytes[i] != _pngSignature[i]) return text;
    }
    final ByteData view = ByteData.sublistView(bytes);
    var offset = 8;
    while (offset + 12 <= bytes.length) {
      final int length = view.getUint32(offset);
      final String type = latin1.decode(bytes.sublist(offset + 4, offset + 8));
      final int dataStart = offset + 8;
      final int dataEnd = dataStart + length;
      if (dataEnd + 4 > bytes.length) break;
      if (type == 'IDAT') break;
      if (type == 'tEXt') {
        final int separator = bytes.indexOf(0, dataStart);
        if (separator > dataStart && separator < dataEnd) {
          text[latin1.decode(bytes.sublist(dataStart, separator))] = latin1
              .decode(bytes.sublist(separator + 1, dataEnd));
        }
      }
      offset = dataEnd + 4;
    }
    return text;
  }

  static String _defaultCacheHome() {
    final String? xdg = Platform.environment['XDG_CACHE_HOME'];
    if (xdg != null && p.isAbsolute(xdg)) return xdg;
    final String home = Platform.environment['HOME'] ?? '';
    return p.join(home, '.cache');
  }
}

class _Identity {
  const _Identity({
    required this.key,
    required this.uri,
    required this.digest,
    required this.modifiedSeconds,
  });

  final String key;
  final String uri;
  final String digest;
  final int modifiedSeconds;
}
