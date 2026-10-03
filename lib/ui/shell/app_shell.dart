import 'package:flutter/material.dart';

import '../../data/services/media_file_picker.dart';
import '../core/widgets/app_top_bar.dart';
import '../folders/folders_screen.dart';
import '../home/home_screen.dart';
import '../library/library_screen.dart';
import '../settings/settings_screen.dart';
import 'app_destination.dart';

/// Main desktop layout with persistent navigation and feature content.
class AppShell extends StatefulWidget {
  const AppShell({
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.historyEnabled,
    required this.resumeEnabled,
    required this.onHistoryEnabledChanged,
    required this.onResumeEnabledChanged,
    required this.onOpenMedia,
    super.key,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final bool historyEnabled;
  final bool resumeEnabled;
  final ValueChanged<bool> onHistoryEnabledChanged;
  final ValueChanged<bool> onResumeEnabledChanged;
  final ValueChanged<String> onOpenMedia;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppDestination _destination = AppDestination.home;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool compact = constraints.maxWidth < 900;
            return Row(
              children: [
                _Sidebar(
                  compact: compact,
                  destination: _destination,
                  onDestinationSelected: (AppDestination destination) {
                    setState(() => _destination = destination);
                  },
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(
                    children: [
                      AppTopBar(
                        title: '',
                        themeMode: widget.themeMode,
                        onOpenFile: _pickAndOpenFile,
                        onOpenSettings: () => setState(
                          () => _destination = AppDestination.settings,
                        ),
                        onThemeModeChanged: widget.onThemeModeChanged,
                      ),
                      Expanded(child: _buildDestination()),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDestination() => switch (_destination) {
    AppDestination.home => const HomeScreen(),
    AppDestination.allVideos => const LibraryScreen(),
    AppDestination.folders => const FoldersScreen(),
    AppDestination.settings => SettingsScreen(
      themeMode: widget.themeMode,
      onThemeModeChanged: widget.onThemeModeChanged,
      historyEnabled: widget.historyEnabled,
      resumeEnabled: widget.resumeEnabled,
      onHistoryEnabledChanged: widget.onHistoryEnabledChanged,
      onResumeEnabledChanged: widget.onResumeEnabledChanged,
    ),
  };

  Future<void> _pickAndOpenFile() async {
    try {
      final String? uri = await pickVideoUri();
      if (uri != null) widget.onOpenMedia(uri);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open the file picker: $error')),
        );
      }
    }
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.compact,
    required this.destination,
    required this.onDestinationSelected,
  });

  final bool compact;
  final AppDestination destination;
  final ValueChanged<AppDestination> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final double width = compact ? 76 : 232;
    return SizedBox(
      width: width,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const SizedBox(height: 12),
            _NavigationItem(
              compact: compact,
              destination: AppDestination.home,
              selected: destination == AppDestination.home,
              icon: Icons.home_outlined,
              label: 'Home',
              onPressed: onDestinationSelected,
            ),
            _NavigationItem(
              compact: compact,
              destination: AppDestination.allVideos,
              selected: destination == AppDestination.allVideos,
              icon: Icons.video_library_outlined,
              label: 'All Videos',
              onPressed: onDestinationSelected,
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(compact ? 10 : 14, 24, 8, 8),
              child: compact
                  ? const Divider()
                  : Text(
                      'FOLDERS',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        letterSpacing: 1.1,
                      ),
                    ),
            ),
            _NavigationItem(
              compact: compact,
              destination: AppDestination.folders,
              selected: destination == AppDestination.folders,
              icon: Icons.folder_outlined,
              label: compact ? 'Folders' : 'Add Folder',
              onPressed: onDestinationSelected,
            ),
            const Spacer(),
            _NavigationItem(
              compact: compact,
              destination: AppDestination.settings,
              selected: destination == AppDestination.settings,
              icon: Icons.settings_outlined,
              label: 'Settings',
              onPressed: onDestinationSelected,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.compact,
    required this.destination,
    required this.selected,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final bool compact;
  final AppDestination destination;
  final bool selected;
  final IconData icon;
  final String label;
  final ValueChanged<AppDestination> onPressed;

  @override
  Widget build(BuildContext context) {
    final Color foreground = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Tooltip(
        message: label,
        child: Material(
          color: selected
              ? Theme.of(context).colorScheme.secondaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => onPressed(destination),
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 46,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 14),
                child: compact
                    ? Center(child: Icon(icon, color: foreground))
                    : Row(
                        children: [
                          Icon(icon, color: foreground, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            label,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: foreground),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
