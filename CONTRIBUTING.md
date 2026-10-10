# Contributing to VPFL

Thank you for considering a contribution. Please open an issue or pull request
describing the change and include relevant checks. Keep existing copyright,
license, and attribution notices in files you modify.

By intentionally submitting a contribution for inclusion in VPFL, you agree
to license your contribution under the applicable license of the files you
change. Original VPFL files are under Apache License 2.0. Some files under
`third_party/media_kit_video` derive from MIT-licensed upstream source;
modifications made directly to those files remain subject to the applicable
upstream-compatible terms and must preserve upstream notices. If your change
has a different license or third-party provenance, identify it in the pull
request before inclusion.

You retain copyright in your own contributions. VPFL does not require you to
assign copyright to Sheikh Muneeb Ahmed. Only submit work you are authorized
to contribute. See [LICENSE](LICENSE), [NOTICE](NOTICE), and
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Testing a change

Run `flutter analyze` and `flutter test` before opening a pull request. For
media, native runner, or packaging changes, follow the reproduction commands
in the [CI guide](docs/ci/README.md). Add a video fixture when changing a
claimed video format. VPFL V1 does not accept standalone audio files. Record
the commands you ran and any unavailable environment in the PR template.

The `ci / required-gate` check is intended for branch protection on
`bootstrap-project` and `main`. A newly written workflow is not a passed
hosted check; review its first actual run before merge.
