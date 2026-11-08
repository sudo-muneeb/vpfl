# VPFL agent instructions

Apply these rules throughout the repository. Read [README.md](README.md) and
[CONTRIBUTING.md](CONTRIBUTING.md) first. If instructions conflict, ask the
owner before changing scope or bypassing a check.

## Find the relevant contract

Read the implementation, callers, tests, and relevant guidance before editing:

   | Change area | Read and verify |
   | --- | --- |
   | New feature, platform, or media format | `GOALS.md`, `docs/01-product-scope-fixed.md`, and the V1 contract in `docs/ci/README.md`; check whether the proposal is in scope before implementing it. |
   | UI, state, or performance | `docs/02-architecture.md`, `docs/04-performance.md`, `docs/06-testing.md`, and the relevant `.agents/` guidance; check rebuild scope, accessibility, and widget tests. |
   | Playback, queues, formats, or subtitles | `docs/02-architecture.md`, `docs/06-testing.md`, `docs/ci/README.md`, and `test/fixtures/media-matrix.json` where formats change; check source switches, completion, errors, and the applicable native playback tests. |
   | Library, filesystem, settings, or database | `docs/02-architecture.md` and `docs/06-testing.md`; check isolated persistence, migration, scan, and failure cases as applicable. |
   | Linux window, native plugin, renderer, or package | `docs/06-testing.md`, `docs/ci/README.md`, and the relevant `docs/compatibility/` guide; check the matching Linux integration or install lane. Consult `docs/ci/release-checklist.md` for release claims. |
   | Documentation only | Check links, commands, claims, and consistency with the current code and neighboring docs. |

Current code and executable checks establish implemented behavior. Design
backlogs and dated investigations are not current support claims.
Documentation-only changes need link, command, and consistency review;
Flutter builds and multimedia tests are unnecessary for those edits.

## Diagnose and implement

Reproduce bugs when practical and trace the complete affected path. State
expected behavior and relevant boundaries before editing, including repeated
operations, invalid input, lifecycle, cancellation, and concurrency. Ask about
ambiguous product choices when they materially change UX.

Fix the root cause with the smallest coherent change. Preserve contracts;
avoid unrelated refactors, speculative abstractions, duplicated state, broad
exception swallowing, and silent fallbacks. Distinguish product defects from
incorrect tests or missing infrastructure. If the cause remains unknown,
report the evidence and unresolved question instead of applying a guess.

## Preserve test integrity

- Test observable behavior at the lowest useful layer. Cover the affected
  class of inputs/transitions, a boundary, and neighboring behavior; use
  deterministic temporary databases/files rather than personal data.
- Demonstrate that a regression test rejects the defect, preferably by running
  it before the fix or with controlled fault injection. Do not mock the
  function under test, mirror its implementation, or assert only no exception.
- Stateful paths must verify transitions and outcomes, including failed opens,
  stale results, completion, recovery, and cleanup where relevant. Native
  playback, rendering, windows, and packages require real Linux evidence.
- Run the relevant existing suite and applicable contributor checks. Investigate
  failures; do not skip/weaken assertions, add fixture-specific exceptions,
  arbitrary sleeps/timeouts, reorder tests, or change environments merely to
  obtain green CI. Test/harness changes need evidence that they improve the
  contract being checked. Review generated output before accepting it.
- Record exact commands, results/exit status, and unrun checks. Never imply
  software GL proves physical GPU decoding or that CI covers untested systems.

## Git authorization and handoff

1. Inspect status and branch before editing. Preserve existing user changes;
   never reset, clean, stash, or overwrite them without permission.
2. Start code work on a topic branch from `main`. If switching could disturb
   existing work, leave the checkout alone and report it.
3. Editing and local checks are authorized by a coding request. **Do not stage,
   commit, amend, push, open a PR, merge, or release without explicit owner
   authorization.** A bug-fix request or contributor guide is not authorization.
4. Review the complete diff and run `git diff --check`. Report the root cause,
   before/after behavior, changed files, checks, failures, and remaining limits
   before requesting any Git action. Leave work unstaged and uncommitted.
5. Keep `main` linear through reviewed PRs. Never commit/push directly to it,
   force-push it, or delete it. Do not call work merge-ready while required
   verification or review is open.
