import 'package:default_manager_linux/default_manager_linux.dart';
import 'package:flutter/material.dart';

import '../../data/services/default_app_prompt_service.dart';

Future<void> confirmAndMakeDefault(
  BuildContext context,
  DefaultAppPromptService service,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Make VPFL your default video player?'),
      content: const Text(
        'Supported video files will open in VPFL when you double-click them. '
        'You can change this later in your desktop settings.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Make default'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    final DefaultAppResult result = await service.makeDefault();
    if (!context.mounted) return;
    final int successful = result.results.values.where((value) => value).length;
    final String failures = result.errors.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join('\n');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? 'VPFL is now the default for $successful video formats.'
              : 'VPFL became default for $successful of '
                    '${result.results.length} formats. $failures',
        ),
      ),
    );
  } on Object catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not change video defaults: $error')),
    );
  }
}

class DefaultAppPromptBanner extends StatelessWidget {
  const DefaultAppPromptBanner({required this.service, super.key});

  final DefaultAppPromptService service;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: service,
    builder: (context, _) {
      if (!service.bannerVisible) return const SizedBox.shrink();
      return Material(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.video_settings_outlined),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Open your video files with VPFL by default?'),
              ),
              TextButton(
                onPressed: service.maybeLater,
                child: const Text('Maybe later'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => confirmAndMakeDefault(context, service),
                child: const Text('Make default'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class DefaultAppSettingsControl extends StatelessWidget {
  const DefaultAppSettingsControl({required this.service, super.key});

  final DefaultAppPromptService service;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: service,
    builder: (context, _) {
      final String status;
      if (service.loading) {
        status = 'Checking desktop defaults…';
      } else if (service.error != null) {
        status = 'Could not check the desktop video defaults.';
      } else if (!service.available) {
        status = 'Available after VPFL is installed as a desktop application.';
      } else if (service.isDefaultForAll) {
        status = 'VPFL is the default for supported video formats.';
      } else if (service.defaultCount == 0) {
        status = 'VPFL is not the default for any supported video formats.';
      } else {
        status =
            '${service.defaultCount} of '
            '${vpflVideoMimeTypes.length} supported video formats use VPFL.';
      }
      final scheme = Theme.of(context).colorScheme;
      final action = service.error != null
          ? TextButton(onPressed: service.refresh, child: const Text('Retry'))
          : service.available && !service.isDefaultForAll && !service.loading
          ? OutlinedButton(
              key: const Key('make-default-button'),
              onPressed: () => confirmAndMakeDefault(context, service),
              child: const Text('Make VPFL default'),
            )
          : null;
      final details = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Default video player',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (service.isDefaultForAll) ...[
                Icon(Icons.check_circle, size: 17, color: scheme.primary),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  status,
                  key: const Key('default-player-status'),
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      );
      return LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 580
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  details,
                  if (action != null) ...[const SizedBox(height: 12), action],
                ],
              )
            : Row(
                children: [
                  Expanded(child: details),
                  if (action != null) ...[const SizedBox(width: 16), action],
                ],
              ),
      );
    },
  );
}
