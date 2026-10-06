import 'package:flutter/material.dart';

import '../themes/vpfl_theme_extension.dart';
import 'window_controls.dart';

/// Shared app bar for the library shell and playback screen.
class AppTopBar extends StatelessWidget {
  const AppTopBar({
    required this.title,
    required this.themeMode,
    required this.onOpenFile,
    required this.onThemeModeChanged,
    this.renderingMode,
    this.onBack,
    super.key,
  });

  final String title;
  final ThemeMode themeMode;
  final VoidCallback onOpenFile;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final String? renderingMode;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<VpflThemeExtension>()!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        return Container(
          height: 60,
          decoration: BoxDecoration(
            color: tokens.topBarBackground,
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
                    height: 60,
                    child: Row(
                      children: [
                        Image.asset(
                          'vpfl-logo.png',
                          width: 29,
                          height: 29,
                          semanticLabel: 'VPFL logo',
                        ),
                        if (!compact) ...[
                          const SizedBox(width: 9),
                          Text('VPFL', style: textTheme.titleMedium),
                        ],
                        if (title.isNotEmpty) ...[
                          const SizedBox(width: 15),
                          SizedBox(
                            height: 20,
                            child: VerticalDivider(
                              color: scheme.outlineVariant,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        if (renderingMode != null) ...[
                          const SizedBox(width: 15),
                          _RendererBadge(mode: renderingMode!),
                        ],
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
              ),
              if (compact)
                IconButton(
                  key: const Key('open-file-button'),
                  tooltip: 'Open file',
                  onPressed: onOpenFile,
                  icon: const Icon(Icons.folder_open_outlined),
                )
              else
                TextButton.icon(
                  key: const Key('open-file-button'),
                  onPressed: onOpenFile,
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onSurface,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  icon: const Icon(Icons.folder_open_outlined, size: 20),
                  label: const Text('Open file'),
                ),
              const SizedBox(width: 4),
              PopupMenuButton<ThemeMode>(
                key: const Key('quick-appearance-menu'),
                tooltip: 'Appearance',
                initialValue: themeMode,
                onSelected: onThemeModeChanged,
                iconSize: 20,
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
              const SizedBox(width: 6),
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
      message: 'Video renderer: $label',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            child: const SizedBox(width: 5, height: 5),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
