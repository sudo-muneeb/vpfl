import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/default_app_prompt_provider.dart';
import 'default_app_controls.dart';

/// Basic appearance settings for the application shell.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({
    required this.themeMode,
    required this.onThemeModeChanged,
    this.historyEnabled = true,
    this.resumeEnabled = true,
    this.onHistoryEnabledChanged,
    this.onResumeEnabledChanged,
    super.key,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final bool historyEnabled;
  final bool resumeEnabled;
  final ValueChanged<bool>? onHistoryEnabledChanged;
  final ValueChanged<bool>? onResumeEnabledChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 28),
        Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Choose how VPFL looks on this desktop.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        SegmentedButton<ThemeMode>(
          key: const Key('theme-mode-selector'),
          segments: const [
            ButtonSegment(
              value: ThemeMode.system,
              icon: Icon(Icons.brightness_auto_outlined),
              label: Text('System'),
            ),
            ButtonSegment(
              value: ThemeMode.light,
              icon: Icon(Icons.light_mode_outlined),
              label: Text('Light'),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              icon: Icon(Icons.dark_mode_outlined),
              label: Text('Dark'),
            ),
          ],
          selected: {themeMode},
          onSelectionChanged: (Set<ThemeMode> selected) {
            onThemeModeChanged(selected.single);
          },
        ),
        const SizedBox(height: 28),
        Text('Playback', style: Theme.of(context).textTheme.titleLarge),
        SwitchListTile(
          key: const Key('history-enabled-setting'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Playback history'),
          subtitle: const Text(
            'Remember videos that start playing. Turning this off keeps existing history.',
          ),
          value: historyEnabled,
          onChanged: onHistoryEnabledChanged,
        ),
        SwitchListTile(
          key: const Key('resume-enabled-setting'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Resume playback'),
          subtitle: const Text('Continue from the last saved position.'),
          value: resumeEnabled,
          onChanged: onResumeEnabledChanged,
        ),
        const SizedBox(height: 28),
        DefaultAppSettingsControl(service: ref.read(defaultAppPromptProvider)),
      ],
    );
  }
}
