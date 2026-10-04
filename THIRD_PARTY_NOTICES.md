# Third-party software and notices

VPFL's original work is licensed under Apache-2.0. Dependencies retain their
own terms. This list describes the dependencies checked for the Linux build
using `pubspec.lock`, package license files, the Flutter SDK license, and the
installed Linux development packages on 4 October 2026. Consult the license
files shipped with the exact versions you redistribute.

## Included in the repository or Linux application bundle

- **media_kit_video 2.0.1** — [upstream](https://github.com/media-kit/media-kit),
  MIT; copyright © 2021 and onward Hitesh Kumar Saini. Its source is vendored
  in `third_party/media_kit_video/`, with its original `LICENSE` and source
  notices preserved. VPFL patches Linux EGL/Flutter rendering and Dart
  integration. See `patches/media_kit_video/README.md` for the modification
  attribution. The modified upstream files continue to carry the MIT notice.
- **media_kit 1.2.6, media_kit_libs_video 1.0.7, and
  media_kit_libs_linux 1.2.1** —
  [upstream](https://github.com/media-kit/media-kit), MIT; copyright © 2021
  and onward Hitesh Kumar Saini. These are Pub dependencies. The Linux libs
  package supplies a plugin; Linux playback uses system libmpv.
- **Flutter engine and framework** — [upstream](https://github.com/flutter/flutter),
  BSD-3-Clause; copyright © 2014 The Flutter Authors. The Linux release
  bundle includes Flutter engine libraries and Flutter-generated
  `data/flutter_assets/NOTICES.Z`, which contains notices for compiled Flutter
  and Dart package components. See also the SDK's `LICENSE`.
- **Dart SDK and runtime components** — [upstream](https://github.com/dart-lang/sdk),
  BSD-3-Clause; copyright © 2012 the Dart project authors. Dart code is
  compiled into the Flutter bundle. Additional component notices appear in
  Flutter's generated `NOTICES.Z`.
- **flutter_riverpod 3.4.3** — [upstream](https://github.com/rrousselGit/riverpod),
  MIT; copyright © Remi Rousselet. Bundled Dart dependency.
- **file_selector 1.1.0 and file_selector_linux 0.9.4+1** —
  [upstream](https://github.com/flutter/packages), BSD-3-Clause; copyright ©
  2013 The Flutter Authors. Bundled Dart and native Linux plugin components.
- **drift 2.35.1 and drift_flutter 0.3.1** —
  [upstream](https://github.com/simolus3/drift), MIT; copyright © Simon Binder.
  Bundled Dart dependencies.
- **cupertino_icons 1.0.9** —
  [upstream](https://github.com/flutter/packages/tree/main/third_party/packages/cupertino_icons),
  MIT; copyright © Vladimir Kharlampidi. Bundled font asset.
- **path 1.9.1 and jni 1.1.0** —
  [Dart packages](https://github.com/dart-lang), BSD-3-Clause; copyright © the
  Dart project authors. Pub dependencies. `libdartjni.so` is included as a
  transitive asset but is not loaded by VPFL on Linux.
- **sqlite3 Dart package 3.5.2** —
  [upstream](https://github.com/simolus3/sqlite3.dart), MIT; copyright © Simon
  Binder. Its bundled SQLite C library is [public domain](https://www.sqlite.org/copyright.html),
  as stated by the SQLite project. The release bundle contains `libsqlite3.so`.

Other transitive Pub packages are pinned in `pubspec.lock`. The Flutter build
generates `NOTICES.Z` from package notices; preserve it when redistributing the
bundle. The list above is not a replacement for those full license texts.

## System libraries used by native Linux packages

- **mpv/libmpv** — [upstream](https://github.com/mpv-player/mpv). VPFL links
  dynamically to the distribution's `libmpv.so.2`; DEB and RPM packages do
  not bundle it. mpv's source and binary license obligations vary with build
  options and linked libraries. The inspected Ubuntu development package
  records GPL/LGPL components, and its binary package records GPL-3+ due to
  linked components. Review the exact distribution package and any
  redistribution scenario separately.
- **libepoxy** — [upstream](https://github.com/anholt/libepoxy), MIT/Expat;
  copyright © 2013–2014 Intel Corporation. Linked dynamically from the
  distribution package. Its registry data carries an additional © 2013
  Khronos Group Inc. notice in the inspected distribution copyright file.
- **GTK, GIO/GLib, EGL/GLES, and other system libraries** — dynamically
  supplied by the target distribution. Their notices and licenses are in the
  corresponding distribution packages; the exact dependency set depends on
  the build and target distribution.

The Flatpak runtime supplies some system libraries under its own notices. A
new release should review `pubspec.lock`, generated `NOTICES.Z`, vendored
sources, and the actual binary dependency tree before publication.
