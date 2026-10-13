## Change

Describe the user-facing behavior and the reason for this change.

For a bug fix, state the root cause. Describe the behavior before and after,
including an important boundary or related behavior that must remain intact.

## Test design

List the new or changed tests and what each proves. Explain how the regression
test would fail with the original bug still present. Include representative,
boundary, and neighboring cases where applicable. If no test was added,
explain why. Documentation only changes can use a consistency review.

## Test evidence

- [ ] `flutter test` and `flutter analyze` run locally
- [ ] Native Linux test run when playback, renderer, or window behavior changes
- [ ] New or changed advertised video format has a manifest fixture and VPFL playback assertion
- [ ] Settings or database changes include isolated persistence or migration coverage
- [ ] Package or desktop integration changes include native install checks
- [ ] Relevant existing tests run alongside new or changed tests

List exact commands and their pass or fail results. State which checks could
not run locally and why. Include CI job links after they run. Do not mark a
check complete based on a plan to run it later.

## Review notes

Note UI screenshots, changed media policy, database schema, package dependencies, and known limitations where relevant. The required CI gate must pass before merge.
