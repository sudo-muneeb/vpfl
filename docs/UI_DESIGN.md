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

Initial structure:

```text
┌──────────────────────────────────────────────────────────────┐
│ VPFL                                            window controls │
├──────────────┬───────────────────────────────────────────────┤
│ Home         │                                               │
│ All Videos   │ Recent videos                                 │
│              │ [card] [card] [card] [card]                  │
│ Folders      │                                               │
│ + Add Folder │ All videos                                    │
│              │ [card] [card] [card] [card]                  │
│ Settings     │ [card] [card] [card] [card]                  │
│              │                                               │
└──────────────┴───────────────────────────────────────────────┘
```

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
* Sidebar should support narrow and normal width modes.
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
* duration when known
* last played time when useful

Clicking the card opens the player.

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
│                         VIDEO                                │
│     prev vidoe                               next video      │
│                                                              │
│                                                              │
│  00:21  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  01:42:13     │
│                                                              │
│  ↶10    ▶/❚❚    ↷10      1×      Shuffle      🔊      ⋮  ⛶ │
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
* shuffle button
* volume/mute
* three-dot overflow menu
* fullscreen

Default seek step can begin at 10 seconds and later become configurable.

## Three-dot player menu

Secondary actions belong here so the primary control bar remains clean.

Initial menu groups can include:

```text
Subtitles
  Auto
  Off
  embedded tracks
  Add subtitle file

Audio
  Auto
  available audio tracks
  Add external audio when supported

Playback
  Repeat mode
  Fit / aspect behavior

Video
  Screenshot
  Media information

Advanced
  subtitle delay
  audio delay
  diagnostics
```

Only show capabilities that are available.

## Shuffle

Shuffle should be visible only when a queue or playlist context exists, or disabled clearly for single-item playback.

Do not pretend shuffle has meaning for one isolated file.

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

System integration changes selected theme tokens only.

It does not replace VPFL component design.

## Typography

Keep typography centralized.

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
