import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/media_file_picker.dart';
import '../../data/services/linux_file_manager_service.dart';
import '../../data/services/media_metadata_service.dart';
import '../../data/playback_service_provider.dart';
import '../../data/persistence_providers.dart';
import '../../data/model/app_database.dart';
import '../core/widgets/app_top_bar.dart';
import '../core/themes/vpfl_theme_extension.dart';
import '../folders/folders_screen.dart';
import '../home/home_screen.dart';
import '../library/library_screen.dart';
import '../library/video_details_panel.dart';
import '../settings/settings_screen.dart';
import 'app_destination.dart';

/// Main desktop layout with persistent navigation and feature content.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.historyEnabled,
    required this.resumeEnabled,
    required this.onHistoryEnabledChanged,
    required this.onResumeEnabledChanged,
    required this.onOpenMedia,
    this.initialDestination = AppDestination.home,
    this.initialSelectedFolder,
    this.onLocationChanged,
    super.key,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final bool historyEnabled;
  final bool resumeEnabled;
  final ValueChanged<bool> onHistoryEnabledChanged;
  final ValueChanged<bool> onResumeEnabledChanged;
  final ValueChanged<String> onOpenMedia;
  final AppDestination initialDestination;
  final SavedFolder? initialSelectedFolder;
  final void Function(AppDestination, SavedFolder?)? onLocationChanged;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late AppDestination _destination = widget.initialDestination;
  late SavedFolder? _selectedFolder = widget.initialSelectedFolder;
  final Set<int> _scanningFolderIds = {};
  final Set<int> _scannedFolderIds = {};
  MediaMetadataService? _metadataService;
  String? _detailsPath;
  final LinuxFileManagerService _fileManagerService =
      const LinuxFileManagerService();

  MediaMetadataService get _metadata =>
      _metadataService ??= MediaMetadataService(
        activeUri: () => ref.read(playbackServiceProvider).loadedMediaUri,
        activeSnapshot: ref.read(playbackServiceProvider).metadataSnapshotFor,
      );

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<SavedFolder>> folders = ref.watch(
      savedFoldersProvider,
    );
    folders.whenData((List<SavedFolder> values) {
      for (final SavedFolder folder in values) {
        _scanFolder(folder);
      }
      if (_selectedFolder != null) {
        _selectedFolder = values
            .where((SavedFolder value) => value.id == _selectedFolder!.id)
            .firstOrNull;
      }
    });
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppTopBar(
              title: '',
              themeMode: widget.themeMode,
              onOpenFile: _pickAndOpenFile,
              onThemeModeChanged: widget.onThemeModeChanged,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool compact = constraints.maxWidth < 900;
                  return Stack(
                    children: [
                      Row(
                        children: [
                          _Sidebar(
                            compact: compact,
                            destination: _destination,
                            selectedFolderId: _selectedFolder?.id,
                            folders: folders.value ?? const <SavedFolder>[],
                            onAddFolder: _addFolder,
                            onFolderSelected: (SavedFolder folder) {
                              setState(() {
                                _selectedFolder = folder;
                                _destination = AppDestination.folders;
                              });
                              widget.onLocationChanged?.call(
                                AppDestination.folders,
                                folder,
                              );
                            },
                            onDestinationSelected:
                                (AppDestination destination) {
                                  setState(() => _destination = destination);
                                  widget.onLocationChanged?.call(
                                    destination,
                                    _selectedFolder,
                                  );
                                },
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(child: _buildDestination()),
                        ],
                      ),
                      if (_detailsPath case final String filePath)
                        Positioned(
                          top: 16,
                          right: 16,
                          bottom: 16,
                          width: math.min(420, constraints.maxWidth - 32),
                          child: VideoDetailsPanel(
                            key: ValueKey(filePath),
                            filePath: filePath,
                            load: _metadata.inspect,
                            onClose: () => setState(() => _detailsPath = null),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDestination() => switch (_destination) {
    AppDestination.home => HomeScreen(
      onOpenMedia: widget.onOpenMedia,
      onShowDetails: _showDetails,
      onShowContainingFolder: _showContainingFolder,
    ),
    AppDestination.allVideos => LibraryScreen(
      onOpenMedia: widget.onOpenMedia,
      onShowDetails: _showDetails,
      onShowContainingFolder: _showContainingFolder,
    ),
    AppDestination.folders => FoldersScreen(
      folder: _selectedFolder,
      onAddFolder: _addFolder,
      onOpenMedia: widget.onOpenMedia,
      onShowDetails: _showDetails,
      onShowContainingFolder: _showContainingFolder,
      onRemoveFolder: _removeFolder,
      onRescan: _selectedFolder == null
          ? null
          : () => _scanFolder(_selectedFolder!, force: true),
    ),
    AppDestination.settings => SettingsScreen(
      themeMode: widget.themeMode,
      onThemeModeChanged: widget.onThemeModeChanged,
      historyEnabled: widget.historyEnabled,
      resumeEnabled: widget.resumeEnabled,
      onHistoryEnabledChanged: widget.onHistoryEnabledChanged,
      onResumeEnabledChanged: widget.onResumeEnabledChanged,
    ),
  };

  void _showDetails(String filePath) {
    setState(() => _detailsPath = filePath);
  }

  Future<void> _showContainingFolder(String filePath) async {
    try {
      await _fileManagerService.showContainingFolder(filePath);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open containing folder: $error')),
        );
      }
    }
  }

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

  Future<void> _addFolder() async {
    try {
      final String? folderPath = await pickLibraryFolder();
      if (folderPath == null || !mounted) return;
      final repository = ref.read(libraryRepositoryProvider);
      final SavedFolder folder = await repository.addFolder(folderPath);
      setState(() {
        _selectedFolder = folder;
        _destination = AppDestination.folders;
      });
      widget.onLocationChanged?.call(AppDestination.folders, folder);
      await _scanFolder(folder, force: true);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not add folder: $error')));
      }
    }
  }

  Future<void> _scanFolder(SavedFolder folder, {bool force = false}) async {
    if (!force && _scannedFolderIds.contains(folder.id)) return;
    if (!_scanningFolderIds.add(folder.id)) return;
    try {
      await ref.read(libraryScannerProvider).scan(folder);
      _scannedFolderIds.add(folder.id);
    } on Object catch (error) {
      debugPrint('Could not scan saved folder ${folder.path}: $error');
    } finally {
      _scanningFolderIds.remove(folder.id);
    }
  }

  Future<void> _removeFolder(SavedFolder folder) async {
    await ref.read(libraryRepositoryProvider).removeFolder(folder);
    if (mounted && _selectedFolder?.id == folder.id) {
      setState(() {
        _selectedFolder = null;
        _destination = AppDestination.folders;
      });
      widget.onLocationChanged?.call(AppDestination.folders, null);
    }
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.compact,
    required this.destination,
    required this.selectedFolderId,
    required this.folders,
    required this.onAddFolder,
    required this.onFolderSelected,
    required this.onDestinationSelected,
  });

  final bool compact;
  final AppDestination destination;
  final int? selectedFolderId;
  final List<SavedFolder> folders;
  final VoidCallback onAddFolder;
  final ValueChanged<SavedFolder> onFolderSelected;
  final ValueChanged<AppDestination> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final double width = compact ? 76 : 232;
    final tokens = Theme.of(context).extension<VpflThemeExtension>()!;
    return ColoredBox(
      color: tokens.sidebarBackground,
      child: SizedBox(
        width: width,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
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
                selected: false,
                icon: Icons.create_new_folder_outlined,
                label: 'Add Folder',
                onPressed: (_) => onAddFolder(),
              ),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: folders.length,
                  itemBuilder: (context, index) {
                    final folder = folders[index];
                    return Padding(
                      padding: EdgeInsets.only(left: compact ? 0 : 10),
                      child: _NavigationItem(
                        compact: compact,
                        destination: AppDestination.folders,
                        selected:
                            destination == AppDestination.folders &&
                            selectedFolderId == folder.id,
                        icon: Icons.folder_outlined,
                        label: folder.displayName,
                        onPressed: (_) => onFolderSelected(folder),
                      ),
                    );
                  },
                ),
              ),
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
      ),
    );
  }
}

class _NavigationItem extends StatefulWidget {
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
  State<_NavigationItem> createState() => _NavigationItemState();
}

class _NavigationItemState extends State<_NavigationItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<VpflThemeExtension>()!;
    final Color foreground = widget.selected
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Tooltip(
        message: widget.label,
        child: AnimatedContainer(
          duration: MediaQuery.maybeOf(context)?.disableAnimations == true
              ? Duration.zero
              : const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: _focused ? tokens.sidebarFocus : Colors.transparent,
            ),
          ),
          child: Material(
            color: widget.selected
                ? tokens.sidebarSelected
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: () => widget.onPressed(widget.destination),
              onFocusChange: (value) => setState(() => _focused = value),
              hoverColor: tokens.sidebarHover,
              focusColor: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 42,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.compact ? 0 : 12,
                  ),
                  child: widget.compact
                      ? Center(child: Icon(widget.icon, color: foreground))
                      : Row(
                          children: [
                            if (widget.selected) ...[
                              Container(
                                width: 3,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: tokens.sidebarFocus,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Icon(widget.icon, color: foreground, size: 19),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Text(
                                widget.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: foreground,
                                      fontWeight: widget.selected
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
