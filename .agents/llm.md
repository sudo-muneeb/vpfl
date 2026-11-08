# Dart and Flutter conventions

Use [Effective Dart](https://dart.dev/effective-dart) for naming, API design,
null safety, and documentation. The earlier copied reference came from
[Flutter's sample guidance](https://github.com/flutter/samples/blob/main/.prompts/llm.md);
consult upstream rather than maintaining a local language manual.

For VPFL:

- Follow `analysis_options.yaml`, `dart format`, and nearby code. Keep imports
  grouped as Dart SDK, packages, then relative project imports.
- Organize UI by feature and data by responsibility; see the
  [source map](../docs/03-project-structure.md). Keep helpers near their owner.
- Use Riverpod for shared services and reactive queries, media_kit streams for
  live player state, and local widget state for local interactions. Avoid
  copying the same state into another controller just to fit a pattern.
- Keep raw SQL and mpv properties behind their repository/service boundaries.
- Make resource ownership explicit. Cancel subscriptions and guard late async
  results against source replacement/unmounting; await ordered shutdown.
- Explain public contracts, failure behavior, and nonobvious decisions in
  comments. Avoid comments that simply repeat the code.
- Preserve upstream notices in vendored code. Maintain Linux playback patches
  using the [patch guide](../patches/media_kit_video/README.md).

The [contributor guide](../CONTRIBUTING.md) owns setup and check commands;
[AGENTS.md](../AGENTS.md) owns diagnosis, testing integrity, and Git authority.
