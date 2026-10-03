import 'package:flutter/material.dart';

import 'window_controls.dart';

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
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        return Container(
          height: 64,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              if (onBack case final VoidCallback back) ...[
                IconButton(
                  tooltip: 'Home',
                  onPressed: back,
                  icon: const Icon(Icons.home_outlined),
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: WindowDragHandle(
                  child: SizedBox(
                    height: 64,
                    child: Row(
                      children: [
                        Image.asset('vpfl-logo.png', width: 30, height: 30),
                        if (!compact) ...[
                          const SizedBox(width: 10),
                          Text('VPFL', style: textTheme.titleMedium),
                        ],
                        if (title.isNotEmpty) ...[
                          const SizedBox(width: 14),
                          SizedBox(
                            height: 26,
                            child: VerticalDivider(
                              color: scheme.outlineVariant,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleSmall,
                            ),
                          ),
                        ],
                        if (renderingMode != null) ...[
                          const SizedBox(width: 10),
                          _RendererBadge(mode: renderingMode!),
                        ],
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
              ),
              if (compact)
                IconButton.filledTonal(
                  key: const Key('open-file-button'),
                  tooltip: 'Open file',
                  onPressed: onOpenFile,
                  icon: const Icon(Icons.folder_open_outlined),
                )
              else
                FilledButton.tonalIcon(
                  key: const Key('open-file-button'),
                  onPressed: onOpenFile,
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text('Open file'),
                ),
              const SizedBox(width: 6),
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
              const SizedBox(width: 8),
              const WindowControlButtons(),
            ],
          ),
        );
      },
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
