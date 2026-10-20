# Subtitle integration (Part 4)

This change uses the generated [subtitle fixtures](../ci/subtitle-fixtures.md)
and the [Part 3 native evidence](../ci/native-subtitle-verification.md). It leaves
`media_kit`, mpv, libass, the fixtures, and VPFL's rendering settings intact.

## Ownership and observed behavior

mpv discovers embedded and matching nearby subtitle files (`sub-auto=exact` on
the tested host), owns the native track list, and selects the effective `sid`.
libass renders ASS and text captions. `media_kit` exposes tracks and the
**requested** selection through `Player.state` and streams. VPFL presents
those streams in its CC menus and handles the user's external file request.

Requested Auto can coexist with a concrete native `sid`: this is the expected
resolution of automatic selection, not a bug. The CC checkmark therefore
follows the requested media_kit track, while VPFL checks native `sid` only
when confirming an explicit track or Off. No extra subtitle selection state
was introduced.

Two defects were confirmed. First, the pinned `media_kit` URI selection uses
mpv `sub-add ... select`; it does not reuse an automatically discovered file.
The Part 3 `nearby_auto_and_repeat` case grew its native track list by two
entries after two requests for the same SRT. Second, a malformed SRT caused
mpv to add no track, while `media_kit` completed the request and reported the
requested URI. The original VPFL picker treated that completion as success.
The malformed VPFL regression failed before this fix. The minimal native
reproductions and logs are in the Part 3 comparison output under ignored
`build/ci-native-subtitles/`.

## VPFL changes

- A local path is compared with native `track-list` `external-filename` after
  resolving file URIs and safe filesystem links. Matching uses the complete
  canonical path, so equal titles and languages do not merge distinct files.
  VPFL selects a matching media_kit track instead of loading another copy.
- A new external file still uses `media_kit`'s `SubtitleTrack.uri` API. VPFL
  waits for the native track to appear and for the matching media_kit track to
  become available before selecting its numeric ID. If mpv adds no track,
  VPFL reports a concise `SubtitleLoadException`, restores the previous valid
  selection when possible, and leaves the video playing. Bounded stream waits
  cover asynchronous track publication; a successful Future or requested URI
  alone is insufficient.
- Subtitle mutations are serialized within the current playback session.
  Source opens and disposal wait for an in-flight mutation; a changed source
  generation prevents a late result from selecting a track on another video.
  The picker checks the same generation when it returns. Repeated clicks
  cannot issue parallel `sub-add` commands for the same file.
- Wide and compact CC menus observe media_kit's track and selection streams.
  They show Auto, Off, native track labels, and the current requested
  selection. Subtitle labels combine title and language when both exist, and
  fall back to language or a track number.

VPFL uses native properties only for file identity and confirmation of
observable native state. It does not scan for sidecars, parse subtitle text,
maintain a separate track registry, or change renderer settings. mpv also
supports `sub-add ... cached`, but the pinned media_kit API does not expose
that flag; selecting an already discovered numeric track keeps normal
operations within media_kit's public interface. See the
[mpv manual](https://mpv.io/manual/stable/#command-interface-sub-add).

## Regression evidence

The Linux integration tests use a real VPFL `PlaybackService`, Flutter video
surface, pinned media_kit, and generated subtitle suite. They assert native
track counts and effective `sid` as well as media_kit state. On the tested
host, an automatically discovered movie had two native subtitle tracks before
and after repeated loads of `movie.srt`; loading one new SRT on a plain video
gave one track, and repeated, symlink, and file URI requests kept it at one.
Adding a different `english.srt` from another directory gave two native
tracks despite the same basename. Switching to a plain video returned to zero
tracks; reopening the nearby movie returned to two.

The malformed SRT gave zero tracks and raised `SubtitleLoadException`. After
a valid SRT was active, another malformed request left its native `sid` and
track count unchanged. A valid ASS then loaded successfully. The fixture set
does not contain a malformed ASS, so that variant is not claimed as tested.
The unit and widget tests cover path identity, requested Auto and Off
checkmarks, labels, CC actions, and track stream updates. The native
integration tests also exercise rapid selection, paused seeking, source
changes, and disposal during loading. A PlayerScreen integration test injects
a deterministic file choice and checks the malformed-file snackbar, preserved
video, successful load through the same CC control afterward, and rejection of
a file choice returned after another video opens.

## Validation and limits

Run the Part 4 Linux cases with:

```bash
for test_file in \
  integration_test/subtitle_integration_test.dart \
  integration_test/subtitle_file_identity_linux_test.dart \
  integration_test/subtitle_lifecycle_linux_test.dart \
  integration_test/subtitle_picker_linux_test.dart; do
  ./scripts/ci/run_display.sh x11 flutter test "$test_file" \
    -d linux --dart-define=VPFL_SUBTITLE_FIXTURES="$PWD/build/ci-video-fixtures"
done
```

Local validation on 14 October 2026:

| Check | Result |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib test integration_test` | 78 Dart files checked after formatting; no changes required. |
| `flutter analyze` | Exit 0; no issues. |
| `flutter test --reporter expanded` | Exit 0; 91 tests passed. |
| `python3 -m unittest discover -s test/ci -p 'test_*.py' -v` | Exit 0; 9 Python tests passed. |
| Fixture generation and verification with `--subtitle-suite` | Exit 0; 31 original fixtures and 20 subtitle suite files generated and verified. |
| `python3 scripts/ci/run_native_subtitle_checks.py --fixtures build/ci-video-fixtures --out build/ci-native-subtitles` | Exit 0; 18/18 mpv and 18/18 media_kit groups passed, including screenshot pixel checks. |
| Four Part 4 Linux test files above, invoked separately | Exit 0; 5 integration cases passed. |
| `integration_test/media_matrix_test.dart` | First run timed out on natural completion of `h264_mp4` at 2.375/2.521 seconds; isolated rerun exited 0 and exercised all 31 cases. No matrix assertion was changed. |
| `integration_test/linux_lifecycle_test.dart` and `integration_test/queue_playback_test.dart` | Exit 0; one case each, with three Home/playback cycles in the lifecycle case. |
| `flutter build linux --release`; `git diff --check` | Exit 0. |

The [Part 3 pixel suite](../ci/native-subtitle-verification.md) is the
rendering regression check. The Part 4 tests assert track and selection
state; they do not validate the final Flutter compositor pixels, detailed
glyph shaping, or every malformed subtitle variant. The wide popup builds
its rows when opened; reopening it reflects later track changes. The compact
dialog listens for changes while open. The picker test injects the chosen
path; it does not automate the desktop file chooser itself.
When mpv omits `external-filename` for an external track, VPFL has no safe
identity to reuse it and may add another entry through media_kit. VPFL does
not guess from title or language.
Run each Linux test file in a separate Flutter invocation on this host; a
single invocation with multiple Linux integration files failed to establish
debug connections after the first app exited.
