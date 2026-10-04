import 'dart:async';

import 'package:default_manager_linux/default_manager_linux.dart';
import 'package:flutter/foundation.dart';

import '../repositories/playback_history_repository.dart';

/// The same concrete video MIME types advertised by the installed desktop entry.
const List<String> vpflVideoMimeTypes = [
  'video/mp4',
  'video/x-matroska',
  'video/webm',
  'video/quicktime',
  'video/vnd.avi',
  'video/mpeg',
  'video/mp2t',
  'video/x-flv',
  'video/x-ms-wmv',
  'video/3gpp',
  'video/3gpp2',
  'video/ogg',
  'application/mxf',
];

const String vpflDesktopId = 'com.app.vpfl.desktop';

/// Owns VPFL's invitation policy; the plugin itself has no prompt policy.
class DefaultAppPromptService extends ChangeNotifier {
  DefaultAppPromptService({
    required this.settings,
    DefaultManagerLinux? manager,
    DateTime Function()? now,
  }) : _manager = manager ?? const DefaultManagerLinux(),
       _now = now ?? DateTime.now;

  static const int firstPromptAfterPlays = 3;
  static const int maxPrompts = 5;
  static const Duration repromptDelay = Duration(days: 21);
  static const String _playsKey = 'defaultAppPlays';
  static const String _promptsKey = 'defaultAppPrompts';
  static const String _lastPromptKey = 'defaultAppLastPromptAt';

  final SettingsRepository settings;
  final DefaultManagerLinux _manager;
  final DateTime Function() _now;
  Future<void>? _initialization;
  Future<void> _playWrites = Future<void>.value();
  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  bool available = false;
  bool bannerVisible = false;
  bool loading = true;
  int playCount = 0;
  int promptCount = 0;
  int defaultCount = 0;
  DateTime? lastPromptAt;
  String? error;
  DefaultAppResult? lastResult;

  bool get isDefaultForAll =>
      available && defaultCount == vpflVideoMimeTypes.length;

  Future<void> initialize() => _initialization ??= _load();

  Future<void> _load() async {
    try {
      playCount = int.tryParse(await settings.getValue(_playsKey) ?? '') ?? 0;
      promptCount =
          int.tryParse(await settings.getValue(_promptsKey) ?? '') ?? 0;
      lastPromptAt = DateTime.tryParse(
        await settings.getValue(_lastPromptKey) ?? '',
      );
      await refresh();
    } on Object catch (cause) {
      error = '$cause';
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<void> refresh() async {
    try {
      available = await _manager.isAvailable(vpflDesktopId);
      if (available) {
        final status = await _manager.getDefaultStatus(
          vpflDesktopId,
          vpflVideoMimeTypes,
        );
        defaultCount = status.values.where((value) => value).length;
      } else {
        defaultCount = 0;
      }
      if (isDefaultForAll) bannerVisible = false;
      error = null;
    } on Object catch (cause) {
      available = false;
      error = '$cause';
    }
    _notify();
  }

  /// Called once for each media item that reaches the playing state.
  Future<void> recordPlay() {
    _playWrites = _playWrites
        .then((_) async {
          await initialize();
          playCount += 1;
          await settings.setValue(_playsKey, '$playCount');
          if (playCount < firstPromptAfterPlays ||
              bannerVisible ||
              promptCount >= maxPrompts) {
            _notify();
            return;
          }
          final DateTime now = _now();
          if (lastPromptAt != null &&
              now.difference(lastPromptAt!) < repromptDelay) {
            _notify();
            return;
          }
          await refresh();
          if (!available || isDefaultForAll) return;
          lastPromptAt = now;
          promptCount += 1;
          await settings.setValue(
            _lastPromptKey,
            now.toUtc().toIso8601String(),
          );
          await settings.setValue(_promptsKey, '$promptCount');
          bannerVisible = true;
          _notify();
        })
        .onError((Object cause, StackTrace stack) {
          error = '$cause';
          _notify();
        });
    return _playWrites;
  }

  void maybeLater() {
    bannerVisible = false;
    _notify();
  }

  Future<DefaultAppResult> makeDefault() async {
    if (!available) {
      throw StateError('Install VPFL before changing desktop defaults.');
    }
    final result = await _manager.setDefaultForMimeTypes(
      vpflDesktopId,
      vpflVideoMimeTypes,
    );
    lastResult = result;
    bannerVisible = false;
    await refresh();
    return result;
  }
}
