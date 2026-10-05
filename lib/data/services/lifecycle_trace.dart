import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

/// Opt-in lifecycle diagnostics: run with VPFL_LIFECYCLE_TRACE=1.
abstract final class LifecycleTrace {
  static final bool enabled =
      Platform.environment['VPFL_LIFECYCLE_TRACE'] == '1';

  static void event(String name, {int? session, String? detail}) {
    if (!enabled) return;
    final fields = <String>[
      'ts=${DateTime.now().toUtc().toIso8601String()}',
      'isolate=${Isolate.current.hashCode}',
      'event=$name',
      if (session != null) 'session=$session',
      if (detail != null) 'detail=$detail',
    ];
    debugPrint('vpfl.lifecycle ${fields.join(' ')}');
  }
}
