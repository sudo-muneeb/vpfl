import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'persistence_providers.dart';
import 'services/default_app_prompt_service.dart';

final Provider<DefaultAppPromptService> defaultAppPromptProvider =
    Provider<DefaultAppPromptService>((Ref ref) {
      final service = DefaultAppPromptService(
        settings: ref.watch(settingsRepositoryProvider),
      );
      ref.onDispose(service.dispose);
      unawaited(service.initialize());
      return service;
    });
