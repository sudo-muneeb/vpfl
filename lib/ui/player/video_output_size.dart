import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Physical mpv output size before Flutter applies the selected video fit.
({int width, int height}) videoOutputSize({
  required Size source,
  required Size viewport,
  required BoxFit fit,
  required double devicePixelRatio,
}) {
  final displayed = switch (fit) {
    BoxFit.contain => applyBoxFit(fit, source, viewport).destination,
    // Preserve the video aspect ratio in mpv so it does not insert its own
    // letterbox. Flutter then crops or stretches this complete video image.
    BoxFit.cover || BoxFit.fill => _coverSize(source, viewport),
    _ => throw ArgumentError.value(fit, 'fit', 'Unsupported video fit'),
  };
  final physicalWidth = displayed.width * devicePixelRatio;
  final physicalHeight = displayed.height * devicePixelRatio;
  final cap = math.min(1.0, 8192 / math.max(physicalWidth, physicalHeight));
  return (
    width: (physicalWidth * cap).round().clamp(1, 8192),
    height: (physicalHeight * cap).round().clamp(1, 8192),
  );
}

Size _coverSize(Size source, Size viewport) {
  final scale = math.max(
    viewport.width / source.width,
    viewport.height / source.height,
  );
  return Size(source.width * scale, source.height * scale);
}

/// Centers the video with its origin on a physical pixel boundary.
Alignment videoOutputAlignment({
  required Size viewport,
  required Size output,
  required BoxFit fit,
  required double devicePixelRatio,
  required Offset viewportOrigin,
}) {
  final logical = output / devicePixelRatio;
  final fitted = applyBoxFit(fit, logical, viewport);
  final displayed = Size(
    logical.width * fitted.destination.width / fitted.source.width,
    logical.height * fitted.destination.height / fitted.source.height,
  );
  double axis(double available, double origin) {
    if (available.abs() < 0.000001) return 0;
    final centered = origin + available * devicePixelRatio / 2;
    final snapped = (centered.roundToDouble() - origin) / devicePixelRatio;
    return 2 * snapped / available - 1;
  }

  return Alignment(
    axis(
      viewport.width - displayed.width,
      viewportOrigin.dx * devicePixelRatio,
    ),
    axis(
      viewport.height - displayed.height,
      viewportOrigin.dy * devicePixelRatio,
    ),
  );
}
