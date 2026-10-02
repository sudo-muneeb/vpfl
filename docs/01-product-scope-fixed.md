# Product scope and feature matrix

# VPFL development plan

a Flutter video player for desktop Linux, developed locally and distributed through Flatpak and eventually Flathub.

VPFL should open quickly, play reliably, remember recent videos and playback positions, and let the user save folders for later browsing. Use media_kit as the playback engine, Flutter for the interface, SQLite for local records, and Linux desktop bridges for installation and system integration. The feature matrix below is the product checklist and the implementation backlog. Every row includes a delivery decision and a verification requirement.

This is a researched implementation plan. No application has been built or benchmarked, and no hardware capability has been verified on the user's machine. Performance figures are proposed targets. A support claim becomes valid only after testing the actual release bundle.

## 1 Key decisions

1. Develop in VS Code with the official Dart and Flutter extensions. Android Studio remains usable for Dart and Flutter; Linux desktop builds use the Linux toolchain. [S01, S02]

2. Start with the published media_kit packages, then pin the exact resolved dependencies and Flutter revision after the compatibility experiment. The checked versions are media_kit 1.2.6, media_kit_video 2.0.1, and media_kit_libs_video 1.0.7. Use the video native dependency package for both video and audio. [S03, S04]

3. Prove Linux rendering and decoding before developing the full interface. The 2.0.1 changelog lists a Flutter 3.38 Linux rendering fix, but later open issue 1404 reports a software fallback on Linux with 2.0.1 and Flutter 3.38.4 or newer. This is conflicting compatibility evidence, not proof that every current combination fails. Test the selected SDK and package combination on the target machine. [S05, S06]

4. Support the main public media_kit playback features. Put additional mpv controls behind a small Linux adapter and expose them only when the packaged backend supports them. [S07, S08]

5. Create a small working Flatpak early. Persistent folder access, native libraries, GPU access, and launcher behavior are architectural requirements.

6. Keep the first release focused on local media, recent items, saved folders, subtitles, playlists, accessibility, and dependable installation. Direct network playback and advanced controls can arrive in the next milestones without changing the architecture.

## 2 Ideal player checklist and implementation mapping

The support column identifies the implementation owner. Engine means a public media_kit API. Native means a lower level mpv bridge with compatibility checks. App means VPFL must implement the behavior. Desktop means a Linux plugin, portal, or runner change. Conditional means support depends on the packaged backend, hardware, or desktop.

The delivery column uses V1 for the first stable release, V1.1 for the next complete feature milestone, and Later for optional or experimental work. Each row remains unchecked until its verification passes.

### Playback and subtitles

| ID | Ideal capability | Support | Delivery | Implementation plan | Verification |

| --- | --- | --- | --- | --- | --- |

| 01 | Common video containers and codecs | Engine and conditional | V1 | Open files through Media. Publish a tested format matrix rather than promising every format. | Play MP4, MKV, WebM, MOV, and AVI fixtures across H.264, HEVC, VP9, and AV1 where present in the backend. |

| 02 | Audio playback | Engine | V1 | Reuse the player session and show a simple audio view when no video track exists. | Test MP3, FLAC, AAC, and Opus; audio stays controllable without a video texture. |

| 03 | Play, pause, stop, and completion | Engine | V1 | Wrap open, play, pause, playOrPause, stop, and completion events in PlaybackService. | Rapid toggles, stop then reopen, and end of media produce consistent state. |

| 04 | Seek bar and exact time entry | Engine | V1 | Use seek with Duration; provide jump to time and configurable short seek steps. Disable seeking on nonseekable inputs. | Test start, middle, end, repeated seeks, and live inputs without known duration. |

| 05 | Speed controls | Engine | V1 | Offer 0.25x to 3x presets and reset through setRate; keep advanced values separate. | Speed changes take effect while UI, timestamps, and completion remain correct. |

| 06 | Volume and mute | Engine and app | V1 | Use setVolume; store the last audible level for mute restoration. Start with a 0 to 100 UI range. | Mute, unmute, zero volume, and session restoration behave consistently. |

| 07 | Independent pitch adjustment | Engine | V1.1 | Enable PlayerConfiguration.pitch and expose setPitch in advanced audio settings. | Compare pitch behavior and CPU cost at multiple rates and pitch values. |

| 08 | Editable playback queue | Engine | V1 | Use Playlist and next, previous, jump, add, remove, and move. Serialize edits. | Reorder or remove the active item, last item, and items while paused. |

| 09 | Repeat and shuffle | Engine | V1 | Expose none, current item, and whole queue repeat modes; use setShuffle and restore app preferences after opening. | Queue navigation remains correct after new open calls and shuffle changes. |

| 10 | Direct network media | Engine and conditional | V1.1 | Accept direct URLs; use Media.httpHeaders when needed; display buffering and cancellation. | Local test server covers range seeking, redirects, authentication errors, and connection loss. |

| 11 | Video track selection | Engine | V1.1 | Build the menu from available tracks and support automatic selection and video disabled mode. | Test a file with multiple video tracks and an audio only selection. |

| 12 | Embedded subtitles | Engine | V1 | Select embedded subtitle tracks, automatic selection, or subtitles off. | Test multilingual MKV tracks, missing language labels, and no subtitle tracks. |

| 13 | External subtitle files and text | Engine | V1 | Use SubtitleTrack.uri for selected files and SubtitleTrack.data for supplied text. | Test SRT and WebVTT, Unicode names, malformed cues, and empty content. |

| 14 | Automatic nearby subtitle discovery | App and desktop | V1 | Match the video stem and language suffix inside an accessible folder. If only the video is granted, offer Add subtitles. | Test movie.en.srt and movie.ur.srt; an ungranted sibling path is never assumed readable. |

| 15 | Subtitle style and advanced formats | Engine and conditional | V1 | Default to native libass rendering for faithful styled subtitles. Add size, outline, position, and style reset. | Test ASS or SSA styling, attachments, Arabic or Urdu text, and bitmap subtitle fixtures when supported. |

| 16 | Subtitle synchronization | Native | V1.1 | Expose a signed subtitle delay through sub-delay with a reset control and per media persistence. | Confirm positive and negative delays, seeking, and track switches. |

| 17 | Audio languages and external audio | Engine | V1 | Use setAudioTrack, automatic or disabled tracks, and AudioTrack.uri for external audio. | Test multilingual tracks and an external audio file with different duration. |

| 18 | Audio output selection | Engine and desktop | V1.1 | Use audio device enumeration and setAudioDevice; recover to automatic output if a device disappears. | Test headphones, Bluetooth removal, and PipeWire with PulseAudio compatibility. |

| 19 | Screenshots | Engine and desktop | V1 | Save JPEG or PNG through the save dialog. Provide a native subtitle inclusion option. | Verify image dimensions, empty frame behavior, cancellation, and subtitle inclusion. |

| 20 | Fit and aspect ratio controls | Engine and app | V1 | Use Video.fit and aspectRatio; add fit, fill, and a clearly reversible zoom mode. | Test portrait content, rotated media, ultrawide video, and resizing. |

| 21 | Fullscreen | Engine and desktop | V1 | Share one fullscreen action between controls and the native window bridge. Restore previous bounds. | Test Escape, double click, monitor changes, and repeated entry or exit. |

| 22 | Keyboard and mouse controls | App | V1 | Centralize Shortcuts and Actions; provide tooltips and a shortcut reference. | Check text fields, menus, and dialogs do not trigger playback shortcuts. |

| 23 | Drag and drop | Desktop and app | V1 | Accept files, folders, and subtitle files through desktop_drop; validate portal paths and define append versus replace behavior. | Drop from Nemo and sandboxed file managers under X11 and Wayland. |

Public playback, track, queue, and source APIs are documented in the Player, Media, SubtitleTrack, and AudioTrack references. Video documents display fit, controls, fullscreen callbacks, and lifecycle options. Screenshot subtitle inclusion is explicitly tied to native libass rendering. [S07, S09, S10, S11, S12, S13]

### Home screen and saved library

| ID | Ideal capability | Support | Delivery | Implementation plan | Verification |

| --- | --- | --- | --- | --- | --- |

| 24 | Recent videos on the main screen | App | V1 | Store successful playback records in SQLite and show recency, thumbnail, and progress. Limit initial results. | Records survive restarting; failed opens do not become successful recents. |

| 25 | Continue watching | App and engine | V1 | Save position regularly and on important transitions. Resume once after opening a seekable file. | Restore within the documented tolerance after closing or killing the app. |

| 26 | History privacy controls | App | V1 | Add remove recent, clear history, and a private playback mode that avoids history and thumbnail creation. | Private sessions leave no history records or new cached previews. |

| 27 | Saved folders | App and desktop | V1 | Persist a folder identity, accessible URI, portal information when available, name, and scan preferences. | Browse after app restart and logout; recover when access is revoked. |

| 28 | Folder browsing | App | V1 | Show breadcrumbs, folders, grid or list views, natural filename sorting, and nested navigation. | Test deep trees, very long names, spaces, and non Latin names. |

| 29 | Library refresh and changes | App | V1 | Perform incremental scans after user refresh and folder entry. Offer optional watching later. | Detect changes without rescanning all metadata or decoding every file. |

| 30 | Search, sort, and filters | App | V1 | Search indexed names and paths; sort by name, last opened, modification time, or known duration. | Search a 10,000 item simulated library while playback remains responsive. |

| 31 | Useful thumbnails | App and desktop | V1 | Resolve thumbnails in this order: valid Freedesktop thumbnail cache, VPFL cached frame, then placeholder. VPFL may capture one frame through media_kit only after playback has naturally started; never seek active playback just to create artwork. | Existing Linux thumbnails are reused when accessible, stale thumbnails are rejected, a played video can gain a VPFL cached frame, and opening or browsing a folder never triggers bulk video decoding. |

| 32 | Favorites and pinning | App | V1.1 | Pin folders and favorite media using stable records. | Favorites survive moves handled through relinking and disappear only on explicit removal. |

| 33 | Saved playlists | App and engine | V1.1 | Persist ordered media references; add cautious M3U import and export with access validation. | Restart preserves order; missing items can be skipped or relinked. |

Saved folders and history are VPFL features. media_kit supplies the playback state used to build them. SQLite operations should run away from the UI isolate. [S14, S15]

### Thumbnail policy

V1 does not add a separate video-thumbnail generator.

Resolve a card image in this order:

```text
1. valid Freedesktop thumbnail cache
2. VPFL cached frame
3. placeholder
```

For Linux desktop thumbnails, look under the standard XDG thumbnail cache when it is accessible. Validate cached entries against the media URI and modification state before reuse.

VPFL keeps its own cache separate. If no reusable thumbnail exists, VPFL may capture a frame through `media_kit` after the video has successfully started and naturally reached a useful frame. Do not seek the active player solely to create a thumbnail.

Folder scanning indexes metadata only. It must not decode every video merely to populate artwork.

Flatpak access to the host thumbnail cache is a separate sandbox consideration. If the cache is not accessible, VPFL falls back to its own cache or a placeholder without requesting broad filesystem permissions.


### Performance and desktop behavior

| ID | Ideal capability | Support | Delivery | Implementation plan | Verification |

| --- | --- | --- | --- | --- | --- |

| 34 | GPU video rendering | Engine and conditional | V1 gate | Request hardware rendering through VideoControllerConfiguration and verify the native path on the selected SDK. | Collect render logs and distinguish hardware texture output from pixel buffer fallback. |

| 35 | Hardware decoding with software fallback | Engine and native | V1 gate | Start with hwdec auto. Provide software decoding and a compatibility render mode. | Query hwdec-current after load; test a supported codec, unsupported codec, and software mode. |

| 36 | Playback diagnostics | Engine and native | V1 | Show resolution, codec, audio parameters, decoder state, errors, and an optional statistics view. | Unknown properties display unavailable instead of crashing or showing stale values. |

| 37 | Fast startup and quiet idle behavior | App | V1 gate | Load cached home data first, initialize playback when needed, and avoid permanent scans or animations. | Measure release startup, memory, idle CPU, and background work. |

| 38 | Launcher icon and Open With | Desktop | V1 | Install desktop entry, icons, and MIME declarations; align Flutter application identity and executable naming. | App appears in Mint's menu, dock grouping is correct, and file manager launch opens the chosen media. |

| 39 | Opening into an existing instance | Desktop and app | V1.1 | Implement a native activation or local IPC bridge and route external opens through the same application actions. | Repeated Open With actions reach the existing window with the chosen replace or append policy. |

| 40 | System media controls | Desktop and app | V1.1 | Implement MPRIS through a Dart D Bus bridge; expose status, metadata, position, and supported actions. | Cinnamon media controls, keyboard media keys, and queue actions work consistently. |

| 41 | Prevent sleep while watching | Engine and desktop | V1 | Use Video wake lock support; verify Linux behavior and use the Inhibit portal if the plugin is insufficient. | Inhibition exists only during active playback and is released on pause, stop, and exit. |

| 42 | Small floating window | Desktop and conditional | V1.1 | Provide a compact window and request always on top where the compositor allows it. | Restore the normal window; do not promise always on top on every Wayland compositor. |

| 43 | Accessibility | App and conditional | V1 gate | Label controls, preserve focus, support scaling and reduced motion, and validate Linux accessibility with Orca. | Keyboard only operation and screen reader checks cover home, menus, and player controls. |

| 44 | Dark and light appearance | App | V1 | Use one token system with system, dark, and light modes. Preserve video contrast in every mode. | Golden tests cover both modes, long titles, and multiple text scales. |

| 45 | Helpful errors and recovery | App | V1 gate | Separate missing file, revoked folder, unavailable codec, network failure, and rendering failure. Offer relevant recovery. | Error injection and corrupted media tests preserve a responsive app. |

| 46 | Durable local data | App | V1 gate | Use transactions, versioned migrations, and a backup strategy before structural database changes. | Migration fixtures, interrupted writes, disk full, and corrupt database recovery. |

| 47 | Reproducible Flatpak build | Desktop | V1 gate | Declare sources and checksums, build offline, and package native dependencies inside the sandbox. | Build without network access during compilation and run without host libmpv installed. |

| 48 | Discoverable release and updates | Desktop | V1 gate | Supply AppStream metadata, screenshots, license, release notes, and an update process. | Lint metadata, install, update, launch, and verify history survives the update. |

Hardware rendering and decoding are separate controls. media_kit documents the render flag and Linux hwdec auto default. MPRIS, application exports, and persistent document access are separate Linux integrations. [S16, S17, S18, S19, S20, S21]

### Advanced and conditional features

| ID | Ideal capability | Support | Delivery | Implementation plan | Verification |

| --- | --- | --- | --- | --- | --- |

| 49 | Chapters | Native | V1.1 | Query chapter count and indexed chapter properties, then seek to chapter times. Add typed node access only if needed. | Test titled, untitled, and absent chapters with the pinned backend. |

| 50 | Frame stepping | Native and conditional | V1.1 | Expose frame step while paused. Treat backward stepping as conditional and potentially slow. | Compare against a frame numbered fixture; disable unavailable operations. |

| 51 | A and B repeat | Native | V1.1 | Set loop points through native properties; display markers and reset both on source changes. | Invalid ordering, clear, seek past end point, and media transitions. |

| 52 | Audio synchronization | Native | V1.1 | Provide signed audio delay and reset; save an override per media if requested. | Verify both directions with a synchronized flash and click fixture. |

| 53 | Equalizer, color, and video filters | Native and conditional | Later | Use a small tested whitelist of properties and filters with defaults and reset. | Check backend support, GPU and CPU costs, and removal of all overrides. |

| 54 | Timeline hover previews | App and native | Later | Treat hover previews as a separate future subsystem. If implemented, generate sparse previews with bounded background work that never seeks or interferes with the active playback session. | Scrubbing the UI does not alter playback, block the player, or create unlimited decoding work. |

| 55 | HDR and multichannel audio claims | Conditional | Later | Test the complete render path, display, driver, and packaged audio backend before advertising support. | Validate output quality on actual hardware; SDR fallback is documented. |

| 56 | Casting, protected streaming, discs, and online subtitle services | Separate integration | Later or excluded | Scope each separately. media_kit is not a turnkey implementation for these services. | A separate feasibility and dependency review precedes any public support claim. |

| 57 | Bounded media ranges | Engine | V1.1 | Support optional Media.start and Media.end for segment playback. Keep resume policy separate from a persistent clip range. | End of range, repeat behavior, and a later full playback work as intended. |

These advanced native controls need capability checks and tests against the exact packaged mpv version. They must not be inferred from mpv's standalone player interface alone. [S08, S09, S22, S23, S24]

## 3 What media_kit supplies

Use the public interface wherever possible. The planned wrapper covers the main publicly documented playback surface:

| API area | Integration in VPFL |

| --- | --- |

| Initialization and lifecycle | MediaKit.ensureInitialized, Player creation, open, stop, and dispose. Keep a single foreground playback session. |

| Media sources | Local URI, bundled asset, or direct URL; optional HTTP headers, extras, start, and end. Extras carry VPFL media record IDs and display information. |

| Queue | Playlist, add, remove, move, next, previous, jump, repeat mode, and shuffle. VPFL stores saved playlists itself. |

| Sound and timing | Volume, playback rate, pitch when enabled, audio track, external audio, and output device. |

| Tracks | Available and selected video, audio, and subtitle tracks, including automatic selection or disabling a track. |

| Subtitles | URI or text sources, Flutter subtitle configuration, or native libass rendering. |

| Display | VideoController and Video, fit, aspect ratio, output scale, controls, focus, fullscreen callbacks, and lifecycle options. |

| Captures | JPEG, PNG, or raw BGRA screenshot bytes; native subtitle inclusion when explicitly enabled. |

| State and events | Playlist, playing, completion, position, duration, volume, rate, pitch, buffering, buffering percentage, buffer position, repeat, shuffle, audio parameters, video parameters, bitrate, devices, tracks, dimensions, subtitle text, logs, and errors. |

| Native extension | NativePlayer command, getProperty, setProperty, observeProperty, and unobserveProperty behind a capability aware adapter. |

The PlayerStream API uses a list of strings for subtitle events. Prefer the published API reference over older README examples when a signature differs. [S07, S08, S09, S14]

Do not build duplicate histories in both mpv and VPFL. VPFL owns recents, resume policy, folder records, favorites, and playlists, while media_kit owns active playback state.

### Subtitle rendering decision

For Linux, start with PlayerConfiguration(libass: true). This preserves native subtitle layout rather than relying only on Flutter's text overlay. Test styled ASS, font attachments, and any bitmap formats to be included in the support list. [S25]

When using the Flutter overlay, SubtitleViewConfiguration controls text appearance and padding. When using native rendering, implement corresponding subtitle settings through the native adapter and verify each against the packaged engine. Changing a Flutter text style alone does not establish that a native ASS subtitle changed. Allow an explicit rendering preference later if users need it. [S12, S25]

Use a native subtitle inclusion switch for screenshots. Flutter overlay text is separate from the engine frame; do not assume that an engine screenshot captures it. [S13]
