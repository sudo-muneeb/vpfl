import 'package:flutter/material.dart';

/// Uses the same font-glyph rendering path as the surrounding Lucide icons.
class SeekTenIcon extends StatelessWidget {
  const SeekTenIcon({required this.forward, super.key});

  final bool forward;

  static const backwardIcon = IconData(0xe000, fontFamily: 'VpflSeek');
  static const forwardIcon = IconData(0xe001, fontFamily: 'VpflSeek');

  @override
  Widget build(BuildContext context) {
    return Icon(forward ? forwardIcon : backwardIcon);
  }
}
