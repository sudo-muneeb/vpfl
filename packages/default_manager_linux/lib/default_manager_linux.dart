// Copyright 2026 Sheikh Muneeb Ahmed
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/services.dart';

/// Per-MIME results after asking the desktop to change its default handler.
class DefaultAppResult {
  const DefaultAppResult({required this.results, required this.errors});

  final Map<String, bool> results;
  final Map<String, String> errors;

  bool get success =>
      results.isNotEmpty &&
      results.values.every((bool value) => value) &&
      errors.isEmpty;
}

/// Linux desktop MIME defaults backed by GIO. The caller owns the MIME list.
class DefaultManagerLinux {
  const DefaultManagerLinux({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('default_manager_linux');

  final MethodChannel _channel;

  Future<bool> isAvailable(String desktopId) async =>
      await _channel.invokeMethod<bool>('isAvailable', desktopId) ?? false;

  Future<String?> getDefaultApplication(String mimeType) =>
      _channel.invokeMethod<String>('getDefaultApplication', mimeType);

  Future<bool> isDefaultForMimeType(String desktopId, String mimeType) async =>
      await getDefaultApplication(mimeType) == desktopId;

  Future<Map<String, bool>> getDefaultStatus(
    String desktopId,
    List<String> mimeTypes,
  ) async {
    final Map<String, bool> result = {};
    for (final String mimeType in mimeTypes.toSet()) {
      result[mimeType] = await isDefaultForMimeType(desktopId, mimeType);
    }
    return result;
  }

  /// Changes only the requested MIME defaults, then verifies each result.
  /// Call this only after an explicit user action.
  Future<DefaultAppResult> setDefaultForMimeTypes(
    String desktopId,
    List<String> mimeTypes,
  ) async {
    final Map<Object?, Object?>? raw = await _channel
        .invokeMethod<Map<Object?, Object?>>(
          'setDefaultForMimeTypes',
          <String, Object>{
            'desktopId': desktopId,
            'mimeTypes': mimeTypes.toSet().toList(),
          },
        );
    if (raw == null) {
      throw StateError('The desktop did not return MIME default results.');
    }
    final Map<Object?, Object?> values =
        raw['results']! as Map<Object?, Object?>;
    final Map<Object?, Object?> failures =
        raw['errors']! as Map<Object?, Object?>;
    return DefaultAppResult(
      results: values.map(
        (key, value) => MapEntry(key as String, value as bool),
      ),
      errors: failures.map(
        (key, value) => MapEntry(key as String, value as String),
      ),
    );
  }
}
