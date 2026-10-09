import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/default_app_prompt_provider.dart';
import 'default_app_controls.dart';

/// Persistent preferences and application information in one desktop page.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({
    required this.themeMode,
    required this.onThemeModeChanged,
    this.historyEnabled = true,
    this.resumeEnabled = true,
    this.onHistoryEnabledChanged,
    this.onResumeEnabledChanged,
    this.loadPackageInfo,
    this.openExternal,
    super.key,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final bool historyEnabled;
  final bool resumeEnabled;
  final ValueChanged<bool>? onHistoryEnabledChanged;
  final ValueChanged<bool>? onResumeEnabledChanged;
  final Future<PackageInfo> Function()? loadPackageInfo;
  final Future<bool> Function(Uri)? openExternal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scrollbar(
      child: SingleChildScrollView(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 34, 32, 52),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text('Settings', style: text.headlineMedium),
                  ),
                  const SizedBox(height: 32),
                  const _SectionHeading(
                    title: 'Appearance',
                    description: 'Choose how VPFL looks on this desktop',
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: 420,
                    child: SegmentedButton<ThemeMode>(
                      key: const Key('theme-mode-selector'),
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('System'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Light'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Dark'),
                        ),
                      ],
                      selected: {themeMode},
                      onSelectionChanged: (selected) =>
                          onThemeModeChanged(selected.single),
                    ),
                  ),
                  const SizedBox(height: 38),
                  const _SectionHeading(title: 'Playback'),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      children: [
                        SwitchListTile(
                          key: const Key('history-enabled-setting'),
                          contentPadding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          title: const Text('Playback history'),
                          subtitle: const Text(
                            'Remember videos that start playing. Existing history is kept when turned off.',
                          ),
                          value: historyEnabled,
                          onChanged: onHistoryEnabledChanged,
                        ),
                        Divider(color: scheme.outlineVariant),
                        SwitchListTile(
                          key: const Key('resume-enabled-setting'),
                          contentPadding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          title: const Text('Resume playback'),
                          subtitle: const Text(
                            'Continue from the last saved position.',
                          ),
                          value: resumeEnabled,
                          onChanged: onResumeEnabledChanged,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 38),
                  const _SectionHeading(title: 'System integration'),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: DefaultAppSettingsControl(
                      service: ref.read(defaultAppPromptProvider),
                    ),
                  ),
                  const SizedBox(height: 44),
                  Divider(color: scheme.outlineVariant),
                  const SizedBox(height: 25),
                  const _SectionHeading(title: 'About'),
                  const SizedBox(height: 18),
                  _AboutSection(
                    loadPackageInfo:
                        loadPackageInfo ?? PackageInfo.fromPlatform,
                    openExternal: openExternal ?? _openExternal,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Future<bool> _openExternal(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.description});

  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(title, style: text.titleLarge)),
        if (description case final String value) ...[
          const SizedBox(height: 4),
          Text(
            value,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

class _AboutSection extends StatefulWidget {
  const _AboutSection({
    required this.loadPackageInfo,
    required this.openExternal,
  });

  final Future<PackageInfo> Function() loadPackageInfo;
  final Future<bool> Function(Uri) openExternal;

  @override
  State<_AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends State<_AboutSection> {
  static final Uri _repositoryUri = Uri.parse(
    'https://github.com/sudo-muneeb/vpfl',
  );
  late Future<PackageInfo> _packageInfo = widget.loadPackageInfo();

  @override
  void didUpdateWidget(covariant _AboutSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loadPackageInfo != widget.loadPackageInfo) {
      _packageInfo = widget.loadPackageInfo();
    }
  }

  Future<void> _openGitHub() async {
    try {
      if (await widget.openExternal(_repositoryUri)) return;
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open GitHub: $error')));
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open GitHub.')));
    }
  }

  Future<void> _showDocument(String title, String asset) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 650,
            maxHeight: (MediaQuery.sizeOf(dialogContext).height - 48).clamp(
              240,
              620,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(dialogContext).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close document',
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: FutureBuilder<String>(
                  future: DefaultAssetBundle.of(dialogContext)
                      .loadString(asset),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('Could not load this document.'),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return Scrollbar(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: SelectableText(snapshot.data!),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'vpfl-logo.png',
                width: 52,
                height: 52,
                semanticLabel: 'VPFL logo',
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('VPFL', style: text.headlineSmall),
                    Text(
                      'Video Player in Flutter for Linux',
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<PackageInfo>(
            future: _packageInfo,
            builder: (context, snapshot) {
              final info = snapshot.data;
              if (info == null || info.version.isEmpty) {
                return const SizedBox.shrink();
              }
              return Text(
                info.buildNumber.isEmpty
                    ? 'Version ${info.version}'
                    : 'Version ${info.version}  ·  Build ${info.buildNumber}',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              );
            },
          ),
          const SizedBox(height: 14),
          Text(
            'VPFL is a free and open-source video player built for the Linux desktop.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'Created by Sheikh Muneeb Ahmed',
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                key: const Key('github-button'),
                onPressed: () => unawaited(_openGitHub()),
                icon: const Icon(Icons.open_in_new, size: 17),
                label: const Text('View on GitHub'),
              ),
              TextButton(
                onPressed: () =>
                    unawaited(_showDocument('Apache License 2.0', 'LICENSE')),
                child: const Text('Apache License 2.0'),
              ),
              TextButton(
                onPressed: () => unawaited(
                  _showDocument(
                    'Third-party notices',
                    'THIRD_PARTY_NOTICES.md',
                  ),
                ),
                child: const Text('Third-party notices'),
              ),
              TextButton(
                onPressed: () =>
                    unawaited(_showDocument('Contributing', 'CONTRIBUTING.md')),
                child: const Text('Contributing'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
