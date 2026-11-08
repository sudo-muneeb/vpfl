# Flutter rendering guidance

Use Flutter's [performance best practices](https://docs.flutter.dev/perf/best-practices)
and [DevTools Performance view](https://docs.flutter.dev/tools/devtools/performance)
for framework details. This replaces a copied web page whose template links
and embedded components did not work in repository Markdown.

VPFL-specific decisions and measurement targets live in
[docs/04-performance.md](../docs/04-performance.md). Apply these UI rules:

- Keep I/O and expensive work out of `build`; isolate frequent playback updates
  from the shell/library. Use lazy builders for collections.
- Prefer immutable/const widgets where practical. Extract independently
  changing subtrees; do not add `RepaintBoundary` without measuring repaint cost.
- Avoid unnecessary intrinsic passes, whole-window blur, clipping, opacity,
  and offscreen layers over playing video. Profile before complicating layout.
- Decode cached artwork near its display size; never decode videos for cards
  during scrolling.
- Keep controls keyboard accessible with meaningful semantics and visible
  focus. Test text scaling and fullscreen activation behavior.
- Diagnose Flutter layout/raster cost, mpv decoding, native video output, and
  compositor presentation separately. Use native evidence for native claims.
