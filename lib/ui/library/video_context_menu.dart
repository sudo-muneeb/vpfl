import 'package:flutter/material.dart';

/// The three actions available on every local video card.
class VideoContextMenu extends StatefulWidget {
  const VideoContextMenu({
    required this.onOpen,
    required this.onShowDetails,
    required this.onShowContainingFolder,
    required this.child,
    this.childFocusNode,
    super.key,
  });

  final VoidCallback onOpen;
  final VoidCallback onShowDetails;
  final VoidCallback onShowContainingFolder;
  final Widget child;
  final FocusNode? childFocusNode;

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
    childFocusNode: widget.childFocusNode,
    consumeOutsideTap: true,
    onClose: () {
      if (widget.childFocusNode?.canRequestFocus == true) {
        widget.childFocusNode!.requestFocus();
      }
    },
    menuChildren: [
      MenuItemButton(
        focusNode: _firstItemFocusNode,
        leadingIcon: const Icon(Icons.play_arrow_outlined),
        onPressed: widget.onOpen,
        child: const Text('Open'),
      ),
      MenuItemButton(
        leadingIcon: const Icon(Icons.info_outline),
        onPressed: widget.onShowDetails,
        child: const Text('Show details'),
      ),
      MenuItemButton(
        leadingIcon: const Icon(Icons.folder_open_outlined),
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
