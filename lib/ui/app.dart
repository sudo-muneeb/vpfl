import 'package:flutter/material.dart';

import 'core/themes/vpfl_theme.dart';
import 'player/player_screen.dart';

/// Root application widget for VPFL.
class VpflApp extends StatelessWidget {
  const VpflApp({
    required this.initialMediaUri,
    required this.startupError,
    super.key,
  });

  final String? initialMediaUri;
  final String? startupError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VPFL',
      theme: VpflTheme.light,
      darkTheme: VpflTheme.dark,
      home: PlayerScreen(
        initialMediaUri: initialMediaUri,
        startupError: startupError,
      ),
    );
  }
}
