# VPFL performance constraints

The authoritative policies and unverified measurement targets are in
[docs/04-performance.md](../docs/04-performance.md). Before changing a hot path:

- Show cached library data without waiting for full scans. Keep scans
  asynchronous, incremental, and bounded; skip unchanged files.
- Isolate position/control updates from unrelated UI. Prefer player streams
  to polling and keep idle screens free of continuous work.
- Resolve thumbnails lazily; never seek the foreground player for artwork.
- Preserve the native video surface's sizing and physical-pixel placement;
  see the [resize investigation](../docs/compatibility/subtitle-resize-recovery.md).
- Measure profile/release builds on a named machine. Separate UI/raster,
  decoder, output, and compositor costs; record media and GPU/driver details.
- Exercise scan while playing, rapid replacement, seek, resize/fullscreen,
  and repeated Home/reopen/shutdown paths where affected. Check resource
  trends after warmup rather than inferring leaks from a single RSS sample.

Do not change renderers, allocators, concurrency limits, or add caching without
profiling evidence and meaningful before/after checks.
