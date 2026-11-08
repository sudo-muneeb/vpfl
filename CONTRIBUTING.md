# Contributing to VPFL

Thanks for helping improve VPFL. Contributions can include bug reports,
documentation, tests, accessibility improvements, and code.

VPFL is a Linux desktop video player. Before proposing a new media format or
platform, check the [current product goals](GOALS.md) and the
[V1 media contract](docs/ci/README.md#v1-media-contract).

## Before you start

- Search existing issues and pull requests for related work. Open an issue for
  a substantial change so its approach can be discussed before implementation.
- For a bug report, include the VPFL version or commit, Linux distribution,
  desktop/session (X11/Wayland), GPU/driver, installation method, steps to
  reproduce, expected and actual behavior, and relevant terminal logs. For
  playback issues, include container/codecs and whether other files work;
  distinguish renderer mode from the decoder shown in Diagnostics. Share
  screenshots or a sample video only when you have permission to do so.
- For a documentation fix or other small, focused change, a pull request is
  enough.

## Set up a development checkout

Use an x86_64 Linux desktop host with Flutter **3.47.5** on `PATH` (the CI
version; Dart is supplied by Flutter). Install a C/C++ toolchain, CMake,
Ninja, pkg-config, GTK 3, libmpv, and libepoxy development packages. On
Ubuntu 24.04 / Linux Mint 22.x:

```bash
sudo apt update
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev \
  liblzma-dev libmpv-dev libepoxy-dev
flutter doctor -v
flutter devices
```

For Fedora and Arch package names and the larger native-test toolchain, inspect
[`scripts/ci/install_dependencies.sh`](scripts/ci/install_dependencies.sh).
That script changes system configuration and is intended for disposable CI
containers, not as a workstation installer. Packaging additionally needs the
[packaging tools](docs/compatibility/native-packages.md#build-prerequisites).

After cloning, from the repository root:

```bash
flutter pub get --enforce-lockfile
flutter run -d linux
```

Keep `pubspec.lock`; do not upgrade dependencies incidentally. Use
`./scripts/debug-isolated.sh [video-file]` for a separate test profile;
`./scripts/debug-isolated.sh --help` lists its options. Normal development
runs use your regular XDG database and cache.

## Code style

Use Effective Dart, the repository's `analysis_options.yaml`, and `dart format`.
UI belongs under its feature, shared themes/widgets under `lib/ui/core`, and
native/SQL/player operations behind their services/repositories. Riverpod
wires shared dependencies and query streams; keep local UI state local.
See the [architecture](docs/02-architecture.md) and
[source map](docs/03-project-structure.md). New comments should explain
contracts and nonobvious decisions. Preserve upstream attribution in vendored
files; use the [patch workflow](patches/media_kit_video/README.md) for updates.

## Make a change

Create a topic branch from the latest `main`:

```bash
git fetch origin
git switch main
git pull --ff-only origin main
git switch -c fix/playback-subtitle-selection
```

Use a short, descriptive branch name; `feat/`, `fix/`, `docs/`, `ci/`, and
`chore/` are useful prefixes. Choose the one that fits the work.

Keep the change focused and add or update tests when behavior changes. If you
change an advertised video format, update the fixture manifest and playback
assertions described in the [CI guide](docs/ci/README.md). For changes to
playback, the Linux runner, or packaging, run the relevant native checks there
as well.

If an AI coding agent is assisting, follow [AGENTS.md](AGENTS.md) as well.
In particular, prepare and review the diff and test evidence before the owner
authorizes staging, committing, pushing, or opening a pull request.

## Write commit messages

Use a [Conventional Commit](https://www.conventionalcommits.org/en/v1.0.0/)
heading: `type(scope): concise imperative description`. Omit the scope when it
adds no useful information. Prefer stable VPFL component names such as
`playback`, `library`, `linux`, and `ui`. Use `feat`, `fix`, `refactor`, `perf`,
`docs`, `test`, `build`, `ci`, or `chore`. Aim for a title under 50 characters;
never exceed 72. Describe the actual change rather than "updates" or
"improvements". Final punctuation is optional. The validator checks the type,
heading format, and length; reviewers assess whether wording is clear.

For example, `docs(linux): clarify required build dependencies`. Add a body
when it preserves a bug's cause, an architectural decision, or a compatibility
constraint. Use a `BREAKING CHANGE:` footer when applicable.

The optional [Git template](.gitmessage) can be enabled per clone with
`git config --local commit.template .gitmessage`. Validate a message with
`python3 scripts/ci/check_commit_messages.py --file PATH`; CI checks new commits
in PRs to `main`. Keep commits coherent. Use squash merge for intermediate
commits, or rebase merge when individual commits are worth preserving. Do not
rewrite shared history to apply the convention retroactively.

Before opening a pull request, run the checks that apply to your change:

```bash
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test --reporter expanded
```

For code changes, run `flutter build linux --release` when your Linux setup
supports it. Documentation-only changes need a link, path, command, and
consistency review, plus `git diff --check`; they do not need Flutter or multimedia checks.
See [testing](docs/06-testing.md) for plugin/Python checks and the native suites
to select for the affected behavior. The [CI guide](docs/ci/README.md) explains
which Markdown paths qualify for the documentation-only PR gate. Record the
commands you ran, their results, and any checks you could not run in the pull request.

## Open a pull request

Open the pull request against `main` and fill out the
[pull request template](.github/PULL_REQUEST_TEMPLATE.md). Keep the Summary
and Testing sections; remove optional sections that do not apply. Give exact
test commands and results, including the regression behavior they establish
and any checks that remain. Include UI screenshots or native test results when
relevant. Keep your branch current with `main` and address failing CI jobs and
review comments. Resolve every review conversation before merging.

Changes reach `main` through pull requests. Do not push directly to `main`,
force-push it, or delete it. Use **Squash and merge** or **Rebase and merge** to
keep its history linear. See the [CI guide](docs/ci/README.md) for the hosted
checks and their coverage.

## Licensing and attribution

By intentionally submitting a contribution for inclusion in VPFL, you agree
to license it under the applicable license of the files you change. Original
VPFL files are under Apache License 2.0. Some files under
`third_party/media_kit_video` derive from MIT-licensed upstream source;
modifications made directly to those files remain subject to the applicable
upstream-compatible terms and must preserve upstream notices. If your change
has a different license or third-party provenance, identify it in the pull
request before inclusion.

You retain copyright in your own contributions. VPFL does not require you to
assign copyright to Sheikh Muneeb Ahmed. Only submit work you are authorized
to contribute, and preserve existing copyright, license, and attribution
notices. See [LICENSE](LICENSE), [NOTICE](NOTICE), and
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
