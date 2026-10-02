import 'package:flutter/material.dart';

import 'core/themes/vpfl_theme.dart';
import 'player/player_screen.dart';
import 'shell/app_shell.dart';

/// Root application widget for VPFL.
class VpflApp extends StatefulWidget {
  const VpflApp({
    required this.initialMediaUri,
    required this.startupError,
    super.key,
  });

  final String? initialMediaUri;
  final String? startupError;

  @override
  State<VpflApp> createState() => _VpflAppState();
}

class _VpflAppState extends State<VpflApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VPFL',
      theme: VpflTheme.light,
      darkTheme: VpflTheme.dark,
      themeMode: _themeMode,
      home: widget.initialMediaUri != null || widget.startupError != null
          ? PlayerScreen(
              initialMediaUri: widget.initialMediaUri,
              startupError: widget.startupError,
            )
          : AppShell(
              themeMode: _themeMode,
              onThemeModeChanged: (ThemeMode themeMode) {
                setState(() => _themeMode = themeMode);
              },
            ),
    );
  }
}
