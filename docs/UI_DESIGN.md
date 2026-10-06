# VPFL UI design

This is the editable visual and interaction specification for VPFL.

The exact colors, dimensions, radii, animations, and typography can be changed later without changing application architecture.

## Design goal

VPFL should feel like its own modern desktop media player.

It should not imitate Ubuntu, Yaru, Android, or another desktop toolkit by default.

Priorities:

```text
video first
clean desktop layout
low visual noise
fast access to recent media
fast folder browsing
controls easy to discover
controls disappear when not needed
keyboard friendly
mouse friendly
```

## Main window

Current desktop structure:

```text
┌──────────────────────────────────────────────────────────────┐
│ VPFL   current title   renderer   Open file   utilities  ─ □ × │
├──────────────┬───────────────────────────────────────────────┤
│ Home         │                                               │
│ All Videos   │ Recent videos                                 │
│              │ [preview] [preview] [preview]                │
│ Folders      │                                               │
│ + Add Folder │ All videos                                    │
│              │ [preview] [preview] [preview]                │
│ Settings     │ [preview] [preview] [preview]                │
│              │                                               │
└──────────────┴───────────────────────────────────────────────┘
```

Flutter draws the top bar and VPFL's own minimize, maximize/restore, and close
buttons. The GTK runner removes system decorations and handles those actions
through a window method channel. The title region drags the window and
double-clicking it toggles maximize. GTK owns the window's resize hit areas:
7 px along each edge and 12 px at each corner. Its native cursors appear on
hover, and a primary-button press starts the window manager's resize drag.
The hit areas are hidden while maximized or fullscreen.
The previous Flutter `Listener` only requested a resize after pointer down, so
the cursor did not change on hover. Keep hover, press, and edge selection in
the GTK runner to avoid two competing resize paths.

For a Linux desktop check, hover all four sides and four corners before
clicking, drag from both side edges, then maximize the window. The resize
cursors should disappear while maximized and return after restoring it.

Buttons use themed hover, focus, and tooltips. The runner sets a 760 × 480
minimum window size.

The shared top bar keeps the canonical red and white VPFL logo, current
filename while playing, understated renderer status, Open file, and
appearance. Settings is reached from the sidebar. The
player uses a Home navigation button. At compact widths, Open file becomes
icon-only with a tooltip.

## Sidebar

Initial items:

```text
Home
All Videos

Folders
+ Add Folder
Saved Folder A
Saved Folder B
Saved Folder C

Settings
```

### Sidebar behavior

* Add Folder opens the system folder picker.
* Added folders appear below the Folders section.
* Clicking a saved folder opens folder browsing for that root.
* Sidebar supports narrow icon-only and normal labeled modes; saved folders
  remain reachable in both.
* One destination at a time uses a soft selected surface and small accent
  indicator. Focus has a visible outline. Add Folder remains an action.
* Do not use Android-style bottom navigation on desktop.

## Home screen

Home contains two primary sections.

### Recent videos

Display recently played media first.

Each card may show:

* cached thumbnail if available
* placeholder if no thumbnail exists
* title
* playback progress
* last played time when useful

Clicking the card opens the player.

Recent and indexed media use a shared video-card component. A 16:9 preview
area sits above the title and short metadata. The preview uses a cached
thumbnail when available and a themed placeholder otherwise. Recent cards
show a red progress line when duration is known. Their watched position is
hidden at rest and appears over the thumbnail on hover or keyboard focus,
without changing the card's size. The full title is available in a tooltip.
Completed videos keep a full progress line and a Completed label; they do not
show a watched-time overlay.
Home uses responsive card rows; the full library and saved-folder views use a
lazy grid. Entering the grid does not decode video or generate thumbnails.

A partially watched item resumes according to the resume policy.

### All videos

Display videos indexed from user-added folders.

Requirements:

* lazy grid
* incremental database query
* natural filename sorting option
* search
* list/grid option later if useful
* placeholder artwork is acceptable for never-played videos

Do not generate expensive previews merely because a card entered the grid.

## Folder browser

Folder browser should show:

```text
breadcrumb path

folders first
videos after folders
```

Possible layout:

```text
Home / Videos / Movies / Sci-Fi

[Folder] Alien
[Folder] Blade Runner

[Video] movie_01.mkv
[Video] movie_02.mp4
```

The user should always understand which saved root is being browsed.

## Player screen

Normal player layout:

```text
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│  ◀                      VIDEO                             ▶  │
│                                                              │
│                                                              │
│  00:21  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  01:42:13     │
│                                                              │
│  ⋮  🔊  CC  speed       ↶10  ▶/❚❚  ↷10       repeat    ⛶ │
└──────────────────────────────────────────────────────────────┘
```

Core controls:

* seek slider
* current time
* total duration
* play/pause
* seek backward
* seek forward
* speed button
* subtitles button
* repeat button
* volume/mute
* three-dot overflow menu
* fullscreen

Default seek step can begin at 10 seconds and later become configurable.

The bottom row has three anchored groups. More options, volume, subtitles,
and speed sit at the left. Ten-second seek and play/pause stay centered in the
video viewport. Repeat and fullscreen sit at the right edge. The seek bar is
above them. The volume slider hides at narrower widths while mute remains
available. Speed opens a rate menu; subtitles always open a menu with Auto,
Off, embedded tracks when present, and Load subtitle file. The latter uses the
native picker for SRT, ASS, SSA, and WebVTT files, then selects the loaded
track. The overflow retains secondary actions.

Previous and next appear at the far sides, halfway down the video when a
multi-item queue exists. Opening a local file builds a queue from video files
in the same directory if folder access permits it. The end buttons disable
at the start and end of the queue. A single file or inaccessible parent
folder has no edge navigation.

When controls are active, a light gray translucent gradient improves their
legibility on bright frames. Controls and edge buttons fade out after idle
time and stop receiving pointer events while hidden. Pointer movement brings
them back. The fullscreen top bar still requires the top activation edge.

## Three-dot player menu

Secondary actions belong here so the primary control bar remains clean.

Initial menu groups can include:

```text
Audio
  Auto
  available audio tracks

Video tracks
  available tracks when more than one exists

Playback
  Repeat mode
  Fit / aspect behavior

Video
  Screenshot
  Media information

Advanced
  diagnostics
```

Only show capabilities that are available.

## Queue playback

Repeat is always available: off, one item, and queue. Shuffle remains part of
playback state but is not a primary control until its queue interaction is
designed. Do not present shuffle as meaningful for an isolated file.

## Fullscreen behavior

Fullscreen should minimize visual interruption.

### Bottom controls

The normal playback controls may appear when:

* the mouse moves
* the user interacts with keyboard playback controls
* playback state needs temporary feedback

Hide them again after a short idle period.

### Fullscreen top bar

The top bar has stricter behavior.

**Do not reveal the fullscreen top bar simply because the mouse moved somewhere on the video.**

Reveal it only when the pointer reaches or enters a small activation region at the top edge.

Conceptually:

```text
top 8 to 16 px activation zone
        ↓
show top bar
```

Moving the pointer in the center or bottom of the video does not reveal the top bar.

The top bar may contain:

* back / exit fullscreen
* media title
* optional queue or window action
* close only if appropriate to the final desktop design

Hide it when the pointer leaves the top interaction region and the timeout expires.

## Cursor behavior in fullscreen

When no controls are visible and the mouse is idle:

```text
hide cursor
```

Mouse movement may restore the cursor and bottom controls.

The top bar still requires entering the top activation zone.

## Keyboard behavior

Initial shortcuts:

```text
Space        Play / Pause
Left         Seek backward
Right        Seek forward
Up           Volume up
Down         Volume down
F            Fullscreen
Esc          Exit fullscreen / dismiss overlay
M            Mute
Ctrl+O       Open file
```

Avoid triggering global playback shortcuts while the user is typing into a text field.

## Hover behavior

Desktop controls should have:

* clear hover state
* tooltip where icon meaning is not obvious
* keyboard focus state
* pressed state

Do not make hover effects expensive or continuously animated.

## Theme and color decisions

All color decisions belong in the theme layer.

No feature widget should hard-code product colors.

Use semantic tokens such as:

```text
appBackground
sidebarBackground
surface
surfaceElevated
playerBackground
textPrimary
textSecondary
accent
accentHover
selected
hover
divider
progressPlayed
progressBuffered
progressRemaining
controlForeground
controlBackground
controlHover
overlayBackground
playerOverlayForeground
playerOverlayTop
playerOverlayMiddle
playerOverlayBottom
playerEdgeBackground
error
warning
success
```

Files:

```text
ui/core/themes/
  vpfl_theme.dart
  vpfl_color_tokens.dart
  vpfl_typography.dart
  vpfl_spacing.dart
  vpfl_radius.dart
  vpfl_theme_extension.dart
  system_theme_adapter.dart
```

### Default behavior

VPFL theme is used by default.

Possible settings:

```text
Appearance

Theme
  VPFL Light
  VPFL Dark
  Follow system brightness

Desktop integration
  Use system accent color
```

The implemented Settings screen also shows the default video-player status
for supported Linux MIME types and a **Make VPFL default** action when its
desktop entry is installed. The action asks for confirmation and reports
per-format failures. After the third successful play, a compact invitation
appears directly below the player top bar with **Maybe later** and
**Make default**. Maybe later delays the next invitation by 21 days; no more
than five invitations are shown. The player controls remain over the video.

System integration changes selected theme tokens only.

It does not replace VPFL component design.

## Typography

VPFL bundles Noto Sans Display Regular and Bold under OFL-1.1 for an offline,
consistent desktop sans-serif. The shared type scale lives in
`ui/core/themes/vpfl_typography.dart`; player timecodes use tabular figures.

Define roles instead of styling text ad hoc:

```text
display
pageTitle
sectionTitle
mediaTitle
body
secondary
caption
controlLabel
```

## Spacing

Define shared spacing tokens.

Example names:

```text
xs
sm
md
lg
xl
pagePadding
sidebarPadding
cardGap
controlGap
```

Exact values can be decided later.

## Radius

Centralize radius roles:

```text
cardRadius
dialogRadius
controlRadius
menuRadius
thumbnailRadius
```

## Animation policy

Animations should be subtle and purposeful.

Good candidates:

* controls fading in/out
* page content transition
* hover transition
* fullscreen overlay appearance

Avoid:

* permanent decorative animations
* large background animations while video plays
* animation that keeps frames rendering while the app is idle

Respect reduced-motion settings when practical.

## Responsive desktop behavior

Design around available width rather than device names.

Suggested modes:

```text
wide desktop
→ full sidebar + multi-column grid

normal desktop
→ normal sidebar + responsive grid

compact window
→ narrow sidebar + reduced columns
```

Use a sensible minimum window size instead of supporting unusably tiny layouts.

## Accessibility

Every icon-only control needs:

* semantic label
* tooltip where appropriate
* keyboard focus
* adequate hit target
* visible focus state

Test increased text scale and keyboard-only operation.
