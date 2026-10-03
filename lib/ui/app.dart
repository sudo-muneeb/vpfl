import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/themes/vpfl_theme.dart';
import 'core/widgets/window_controls.dart';
import '../data/persistence_providers.dart';
import 'player/player_screen.dart';
import 'shell/app_shell.dart';

/// Root application widget for VPFL.
class VpflApp extends ConsumerStatefulWidget {
  const VpflApp({
    required this.initialMediaUri,
    required this.startupError,
    super.key,
  });

  final String? initialMediaUri;
  final String? startupError;

  @override
  ConsumerState<VpflApp> createState() => _VpflAppState();
}

class _VpflAppState extends ConsumerState<VpflApp> {
  ThemeMode _themeMode = ThemeMode.system;
  bool _historyEnabled = true;
  bool _resumeEnabled = true;
  late String? _activeMediaUri = widget.initialMediaUri;
  late String? _activeStartupError = widget.startupError;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final settings = ref.read(settingsRepositoryProvider);
      final String? theme = await settings.getValue('themeMode');
      final bool history = await settings.getBool(
        'historyEnabled',
        defaultValue: true,
      );
      final bool resume = await settings.getBool(
        'resumeEnabled',
        defaultValue: true,
      );
      if (!mounted) return;
      setState(() {
        _themeMode = ThemeMode.values.firstWhere(
          (ThemeMode mode) => mode.name == theme,
          orElse: () => ThemeMode.system,
        );
        _historyEnabled = history;
        _resumeEnabled = resume;
      });
    } on Object catch (error) {
      debugPrint('Could not load VPFL preferences: $error');
    }
  }

  void _persist(Future<void> operation) {
    unawaited(
      operation.catchError((Object error) {
        debugPrint('Could not save VPFL preference: $error');
      }),
    );
  }

  void _setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
    _persist(
      ref.read(settingsRepositoryProvider).setValue('themeMode', mode.name),
    );
  }

  void _setHistoryEnabled(bool value) {
    setState(() => _historyEnabled = value);
    _persist(
      ref.read(settingsRepositoryProvider).setBool('historyEnabled', value),
    );
  }

  void _setResumeEnabled(bool value) {
    setState(() => _resumeEnabled = value);
    _persist(
      ref.read(settingsRepositoryProvider).setBool('resumeEnabled', value),
    );
  }

  void _openMedia(String uri) {
    setState(() {
      _activeMediaUri = uri;
      _activeStartupError = null;
    });
  }

  void _returnToLibrary() {
    setState(() {
      _activeMediaUri = null;
      _activeStartupError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VPFL',
      debugShowCheckedModeBanner: false,
      theme: VpflTheme.light,
      darkTheme: VpflTheme.dark,
      themeMode: _themeMode,
      builder: (context, child) =>
          WindowResizeBorder(child: child ?? const SizedBox.shrink()),
      home: _activeMediaUri != null || _activeStartupError != null
          ? PlayerScreen(
              initialMediaUri: _activeMediaUri,
              startupError: _activeStartupError,
              onOpenMedia: _openMedia,
              onBack: _returnToLibrary,
              themeMode: _themeMode,
              onThemeModeChanged: _setThemeMode,
              historyEnabled: _historyEnabled,
              resumeEnabled: _resumeEnabled,
              onHistoryEnabledChanged: _setHistoryEnabled,
              onResumeEnabledChanged: _setResumeEnabled,
            )
          : AppShell(
              themeMode: _themeMode,
              onThemeModeChanged: _setThemeMode,
              historyEnabled: _historyEnabled,
              resumeEnabled: _resumeEnabled,
              onHistoryEnabledChanged: _setHistoryEnabled,
              onResumeEnabledChanged: _setResumeEnabled,
              onOpenMedia: _openMedia,
            ),
    );
  }
}
