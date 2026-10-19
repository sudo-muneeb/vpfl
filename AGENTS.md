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

1. When behavior changes, add or update tests at the lowest useful layer. A regression test should fail on the old behavior when practical, then pass with the fix. Explain when that cannot be demonstrated.

2. Do not write a test that merely repeats the reported input, copies the implementation, mocks the function under test, or asserts only that no exception occurred. Cover a representative class of inputs and the relevant boundary or neighboring case. Use table driven cases when they make the intended rule clearer. Keep tests independent and deterministic.

3. Verify both the new behavior and an existing behavior that could regress. For errors, source switching, playback completion, shutdown, persistence, and other stateful paths, test the transition and observable outcome, including failure handling. Use real Linux integration tests for claims about native media playback, rendering, window behavior, or installed packages.

4. A focused test passing is not enough. Run the existing relevant suite, then the applicable checks in `CONTRIBUTING.md`. If a check fails, investigate it; do not delete, skip, weaken, or rewrite a test simply to obtain a pass. Do not update snapshots or generated files without checking the result.

5. Never claim an unrun test passed. Record exact commands, exit status, and relevant output. If the environment lacks Flutter, Linux display services, codecs, or packaging dependencies, state the gap and the validation still needed. CI success does not prove behavior outside its documented coverage.

6. Documentation only changes need an accurate link and consistency review; they do not need new Flutter tests. See `docs/06-testing.md` for detailed test placement and native checks.

7. **Fix root causes, not symptoms.** Whenever an error, failing test, or unexpected behavior occurs, do not introduce hardcoded fixes, fixture specific exceptions, arbitrary delays, increased timeouts, skipped assertions, or workarounds merely to make the test pass or turn CI green. Trace the complete execution flow, reproduce the failure under controlled conditions, and identify whether the actual cause lies in application logic, architecture, asynchronous state, dependencies, test design, or the execution environment. Distinguish genuine product defects from incorrect test assumptions. Do not modify production behavior to accommodate a broken test, and do not weaken a valid test to accommodate broken production behavior. Implement the smallest correct, generalized fix that addresses the underlying cause rather than hiding its symptoms. Every permanent change must have a clear technical justification supported by evidence. If the root cause remains unknown, continue investigating or report the unresolved findings instead of applying speculative patches.

8. **Test general behavior, not individual failures.** Do not create narrowly tailored tests that only reproduce the exact filename, input, error message, or sequence that previously failed. Investigate what broader class of failures the issue represents and design reusable, behavior focused tests that validate the system's contracts and invariants across representative inputs, boundary conditions, and realistic user interactions. Actively examine what the existing test suite fails to cover, including related edge cases, invalid states, concurrent operations, asynchronous races, resource failures, repeated operations, lifecycle transitions, cancellation, recovery, and interactions between components. Consider failures that have not yet occurred but could reasonably arise from the same underlying weakness. Use parameterized or table driven testing when appropriate, without multiplying redundant tests. Favor meaningful coverage of entire behavioral categories over accumulating isolated regression tests.

9. **Prove that tests can detect broken behavior.** A passing test is not automatically a meaningful test. Where practical, introduce controlled negative cases or fault injection to demonstrate that the assertions reject incorrect behavior, including missing completion events, stale state, wrong source selection, failed recovery, invalid transitions, and unexpected output. Ensure that tests cannot pass merely because a convenient state eventually appears, an exception is suppressed, or a mocked dependency returns the expected value. Verify actual observable outcomes and preserve the distinction between successful requests, completed operations, and correct final behavior. Avoid tests that merely mirror the implementation and would continue passing if the implementation were fundamentally wrong.

10. **Never optimize for green CI at the expense of correctness.** Do not restructure tests, change execution order, isolate cases, increase deadlines, modify fixtures, or alter CI environments solely because doing so eliminates a failure. Such changes are acceptable only when evidence establishes that the existing test setup is incorrect and the replacement more accurately verifies intended behavior. Compare behavior before and after the change, verify neighboring functionality, and check for regressions across relevant environments. Do not introduce unnecessary abstractions, defensive code, or special handling without a demonstrated need. The objective is not to make the current failure disappear; it is to improve the correctness, reliability, maintainability, and general robustness of the entire system while strengthening the test suite's ability to detect future defects.

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
