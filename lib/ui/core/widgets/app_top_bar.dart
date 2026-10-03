import 'package:flutter/material.dart';

/// Shared app bar for the library shell and playback screen.
class AppTopBar extends StatelessWidget {
  const AppTopBar({
    required this.title,
    required this.themeMode,
    required this.onOpenFile,
    required this.onOpenSettings,
    required this.onThemeModeChanged,
    this.renderingMode,
    this.onBack,
    super.key,
  });

  final String title;
  final ThemeMode themeMode;
  final VoidCallback onOpenFile;
  final VoidCallback onOpenSettings;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final String? renderingMode;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            if (onBack case final VoidCallback back) ...[
              IconButton(
                tooltip: 'Back to library',
                onPressed: back,
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
            ],
            Image.asset('vpfl-logo.png', width: 34, height: 34),
            const SizedBox(width: 10),
            Text('VPFL', style: textTheme.titleMedium),
            Expanded(
              child: Row(
                children: [
                  if (title.isNotEmpty) ...[
                    const SizedBox(width: 20),
                    const VerticalDivider(indent: 16, endIndent: 16),
                    const SizedBox(width: 16),
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium,
                      ),
                    ),
                  ],
                  if (renderingMode != null) ...[
                    const SizedBox(width: 12),
                    _RendererBadge(mode: renderingMode!),
                  ],
                ],
              ),
            ),
            FilledButton.tonalIcon(
              key: const Key('open-file-button'),
              onPressed: onOpenFile,
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('Open file'),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<ThemeMode>(
              key: const Key('quick-appearance-menu'),
              tooltip: 'Appearance',
              initialValue: themeMode,
              onSelected: onThemeModeChanged,
              icon: const Icon(Icons.palette_outlined),
              itemBuilder: (BuildContext context) => const [
                PopupMenuItem(
                  value: ThemeMode.system,
                  child: Text('System appearance'),
                ),
                PopupMenuItem(
                  value: ThemeMode.light,
                  child: Text('Light appearance'),
                ),
                PopupMenuItem(
                  value: ThemeMode.dark,
                  child: Text('Dark appearance'),
                ),
              ],
            ),
            IconButton(
              key: const Key('top-bar-settings-button'),
              tooltip: 'Settings',
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

class _RendererBadge extends StatelessWidget {
  const _RendererBadge({required this.mode});

  final String mode;

  @override
  Widget build(BuildContext context) {
    final String label = switch (mode) {
      'gpu' => 'GPU rendering',
      'software' => 'Software rendering',
      'unavailable' => 'Renderer unavailable',
      _ => 'Detecting renderer…',
    };
    return Tooltip(
      message: 'Video renderer',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(label, style: Theme.of(context).textTheme.labelSmall),
        ),
      ),
    );
  }
}
