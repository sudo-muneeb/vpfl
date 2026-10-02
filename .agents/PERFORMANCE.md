
Flutter

1. Never perform expensive computation inside build().
2. Keep rebuild scope as small as practical.
3. Prefer const constructors.
4. Extract independently changing UI into separate widgets.
5. Prefer StatelessWidget over UI helper methods.
6. Use lazy ListView/GridView builders for media collections.
7. Avoid unnecessary Opacity.
8. Avoid unnecessary clipping.
9. Avoid saveLayer dependent effects when simpler rendering works.
10. Avoid expensive intrinsic layouts in large lists.
11. Decode thumbnails close to their displayed resolution.
12. Move CPU intensive media/indexing work away from the UI isolate.
13. Consider RepaintBoundary only for independently repainting expensive regions.
14. Profile before introducing performance specific complexity.

Linux

1. Benchmark using profile and release builds, never debug.
2. Keep Flutter's default Impeller renderer unless profiling demonstrates a reason to change it.
3. Test Wayland and X11.
4. Test window resize, maximize and fullscreen.
5. Test at 1080p, 1440p and 4K when possible.
6. Watch CPU, GPU, VRAM and RAM usage during playback.
7. Ensure idle screens do not continuously trigger animations or rebuilds.
8. Avoid unnecessary full window animations or repaints.
9. Keep the media/video surface isolated from unrelated UI state changes.
10. Test Mesa and NVIDIA drivers where possible.
11. Use DevTools Performance View to inspect UI and raster frame cost.
12. Treat Linux compositor or Flutter engine issues separately from Dart application bottlenecks.

VPFL

1. Player position updates must not rebuild the whole application.
2. Video playback must not rebuild the media library.
3. Thumbnail loading must be lazy.
4. Folder scanning must not block the UI.
5. Conversion progress updates should rebuild only the relevant progress UI.
6. Do not continuously poll player state when media_kit streams can provide events.
7. Keep fullscreen player UI lightweight.
8. Avoid large transparent overlays over the entire video surface.
9. Pause unnecessary animations when controls are hidden.
10. Benchmark while actual 1080p and 4K video is playing.