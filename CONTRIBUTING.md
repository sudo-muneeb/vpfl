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
  steps to reproduce, expected and actual behavior, and relevant logs. Share
  screenshots or a sample video only when you have permission to do so.
- For a documentation fix or other small, focused change, a pull request is
  enough.

## Set up a development checkout

Use a Linux host with the Flutter SDK on `PATH`. CI uses Flutter **3.47.5**;
using that version gives the closest match. Install the Linux build
dependencies described in the [README](README.md#run-from-source),
then, from the repository root, run:

```bash
flutter pub get --enforce-lockfile
flutter run -d linux
```

To run the app with a separate local profile, use
`./scripts/debug-isolated.sh`. See the [README](README.md#run-from-source) for
the command, or run `./scripts/debug-isolated.sh --help` for its options.

## Make a change

Create a topic branch from the latest `main`:

```bash
git fetch origin
git switch main
git pull --ff-only origin main
git switch -c your-topic-branch
```

Keep the change focused and add or update tests when behavior changes. If you
change an advertised video format, update the fixture manifest and playback
assertions described in the [CI guide](docs/ci/README.md). For changes to
playback, the Linux runner, or packaging, run the relevant native checks there
as well.

If an AI coding agent is assisting, follow [AGENTS.md](AGENTS.md) as well.
In particular, prepare and review the diff and test evidence before the owner
authorizes staging, committing, pushing, or opening a pull request.

Before opening a pull request, run the checks that apply to your change:

```bash
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
```

For code changes, run `flutter build linux --release` when your Linux setup
supports it. Documentation-only changes need a link and spelling review; they
do not need a Flutter build. Record the commands you ran, their results, and
any checks you could not run in the pull request.

## Open a pull request

Open the pull request against `main` and fill out the
[pull request template](.github/PULL_REQUEST_TEMPLATE.md). Explain the reason
for the change, its user-visible effect, and how you tested it. Include UI
screenshots or native test results when relevant. Keep your branch current with
`main` and address failing CI jobs and review comments. Resolve every review
conversation before merging.

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
