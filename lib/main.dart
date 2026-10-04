// Copyright 2026 Sheikh Muneeb Ahmed
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'routing/media_open_request.dart';
import 'ui/app.dart';

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  MediaOpenRequest? request;
  String? argumentError;
  try {
    request = MediaOpenRequest.parseArguments(arguments);
  } on FormatException catch (error) {
    argumentError = error.message;
  }

  runApp(
    ProviderScope(
      child: VpflApp(
        initialMediaUri: request?.uri,
        startupError: argumentError,
      ),
    ),
  );
}
