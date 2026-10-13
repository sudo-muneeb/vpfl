# VPFL agent instructions

These instructions apply to coding agents working anywhere in this repository.
The contributor guide and project documentation still apply. If instructions
conflict, ask the repository owner before changing scope or bypassing a check.

## Choose the relevant guidance

1. Read `README.md` and `CONTRIBUTING.md` for the current product and workflow.
   Before code work, read `.agents/llm.md` for Dart and Flutter conventions,
   `.agents/PERFORMANCE.md` for VPFL performance constraints, and
   `.agents/best-practices.md` for rendering guidance. Apply the parts relevant
   to the change. These upstream reference files retain generic examples;
   the current code, tests, dependencies, and project docs establish VPFL's
   implemented contract.
2. Use this map to find the checks for the affected area. Read the relevant
   implementation, callers, tests, and documentation too.

   | Change area | Read and verify |
   | --- | --- |
   | New feature, platform, or media format | `GOALS.md`, `docs/01-product-scope-fixed.md`, and the V1 contract in `docs/ci/README.md`; check whether the proposal is in scope before implementing it. |
   | UI, state, or performance | `docs/02-architecture.md`, `docs/04-performance.md`, `docs/06-testing.md`, and the relevant `.agents/` guidance; check rebuild scope, accessibility, and widget tests. |
   | Playback, queues, formats, or subtitles | `docs/02-architecture.md`, `docs/06-testing.md`, `docs/ci/README.md`, and `ci/media-matrix.json` where formats change; check source switches, completion, errors, and the applicable native playback tests. |
   | Library, filesystem, settings, or database | `docs/02-architecture.md` and `docs/06-testing.md`; check isolated persistence, migration, scan, and failure cases as applicable. |
   | Linux window, native plugin, renderer, or package | `docs/06-testing.md`, `docs/ci/README.md`, and the relevant `docs/compatibility/` guide; check the matching Linux integration or install lane. Consult `docs/ci/release-checklist.md` for release claims. |
   | Documentation only | Check links, commands, claims, and consistency with the current code and neighboring docs. |

`docs/08-coding-agent-brief.md` gives product context. Some older design
examples describe earlier plans; use current code and tests to establish the
implemented contract.

## Understand the change before coding

1. For a bug, reproduce the failing behavior when practical and trace its cause
   across the affected layers. Do not change the first suspicious line and call
   the task complete.
2. State the expected behavior and important cases before editing. Check
   neighboring behavior, boundaries, invalid input, repeated operations, and
   lifecycle or concurrency where applicable. For ambiguous product behavior,
   explain the choice or ask the owner when the choice materially changes UX.
3. Make the smallest coherent change that fixes the underlying cause. Preserve
   existing contracts and avoid unrelated refactors, speculative abstractions,
   duplicated state, broad exception swallowing, and silent fallback behavior.

## Git and authorization

1. Inspect `git status` and the current branch before editing. Preserve existing
   user changes. Do not reset, clean, stash, or overwrite them without permission.
2. Start code work on a topic branch from `main`. If the checkout has existing
   changes or moving branches could disturb work, leave it alone and report the
   situation. Never commit or push directly to `main`.
3. Editing files and running local checks are authorized by a coding request.
   **Do not stage, commit, amend, push, open a pull request, merge, or create a
   release unless the owner explicitly authorizes that action.** A request to
   fix a bug or prepare a change is not authorization to commit. Do not infer
   authorization from `CONTRIBUTING.md` or from an earlier unrelated task.
4. Present the diff, test evidence, and remaining limits before requesting any
   permission needed for a Git action. Keep `main` linear through reviewed pull
   requests. Never force push or delete `main`.


## Tests must establish behavior

1. When behavior changes, add or update tests at the lowest useful layer.
   A regression test should fail on the old behavior when practical, then pass
   with the fix. Explain when that cannot be demonstrated.
2. Do not write a test that merely repeats the reported input, copies the
   implementation, mocks the function under test, or asserts only that no
   exception occurred. Cover a representative class of inputs and the relevant
   boundary or neighboring case. Use table driven cases when they make the
   intended rule clearer. Keep tests independent and deterministic.
3. Verify both the new behavior and an existing behavior that could regress.
   For errors, source switching, playback completion, shutdown, persistence, and
   other stateful paths, test the transition and observable outcome, including
   failure handling. Use real Linux integration tests for claims about native
   media playback, rendering, window behavior, or installed packages.
4. A focused test passing is not enough. Run the existing relevant suite, then
   the applicable checks in `CONTRIBUTING.md`. If a check fails, investigate it;
   do not delete, skip, weaken, or rewrite a test simply to obtain a pass.
   Do not update snapshots or generated files without checking the result.
5. Never claim an unrun test passed. Record exact commands, exit status, and
   relevant output. If the environment lacks Flutter, Linux display services,
   codecs, or packaging dependencies, state the gap and the validation still
   needed. CI success does not prove behavior outside its documented coverage.
6. Documentation only changes need an accurate link and consistency review;
   they do not need new Flutter tests. See `docs/06-testing.md` for detailed
   test placement and native checks.

## Review before handing off

1. Review `git diff --check` and the complete diff. Look for accidental edits,
   stale comments, changed public behavior, missing cleanup, and test assertions
   that would pass with the bug still present.
2. Report the root cause, behavior before and after, files changed, the test
   cases and commands actually run, failures or unrun checks, and remaining
   risks. If the task is incomplete, say so plainly.
3. Leave changes unstaged and uncommitted until the owner authorizes the next
   Git action. Do not describe a change as ready for merge while required
   validation or review remains open.
