import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/themes/vpfl_popup_style.dart';

/// The three actions available on every local video card.
class VideoContextMenu extends StatefulWidget {
  const VideoContextMenu({
    required this.onOpen,
    required this.onShowDetails,
    required this.onShowContainingFolder,
    required this.child,
    super.key,
  });

  final VoidCallback onOpen;
  final VoidCallback onShowDetails;
  final VoidCallback onShowContainingFolder;
  final Widget child;

  @override
  State<VideoContextMenu> createState() => _VideoContextMenuState();
}

class _VideoContextMenuState extends State<VideoContextMenu> {
  final MenuController _controller = MenuController();
  final FocusNode _firstItemFocusNode = FocusNode();

  @override
  void dispose() {
    _firstItemFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MenuAnchor(
    controller: _controller,
    style: VpflPopupStyle.menu(context),
    consumeOutsideTap: true,
    menuChildren: [
      MenuItemButton(
        style: VpflPopupStyle.item(context),
        focusNode: _firstItemFocusNode,
        leadingIcon: const Icon(LucideIcons.circlePlay, size: 19),
        onPressed: widget.onOpen,
        child: const Text('Open'),
      ),
      MenuItemButton(
        style: VpflPopupStyle.item(context),
        leadingIcon: const Icon(LucideIcons.receiptText, size: 19),
        onPressed: widget.onShowDetails,
        child: const Text('Show details'),
      ),
      MenuItemButton(
        style: VpflPopupStyle.item(context),
        leadingIcon: const Icon(LucideIcons.folderKanban, size: 19),
        onPressed: widget.onShowContainingFolder,
        child: const Text('Show containing folder'),
      ),
    ],
    builder: (context, controller, child) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: (details) {
        controller.open(position: details.localPosition);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && controller.isOpen) _firstItemFocusNode.requestFocus();
        });
      },
      child: child,
    ),
    child: widget.child,
  );
}
