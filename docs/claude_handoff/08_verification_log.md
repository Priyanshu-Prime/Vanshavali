# Verification Log

## Ancestry-cycle app-level guard (`wouldCreateAncestryCycle`)
- `flutter test` run directly this pass: **87/87 pass** (up from 78 — 9 new
  tests in `test/screens/family/relation_guards_test.dart` covering
  self-reference, an unrelated-member non-cycle, direct/multi-generation/
  maternal-branch-only cycles, a legitimate sibling-of-a-descendant
  non-cycle, dead-end termination, the `maxVisited` bound, and a
  null-resolver case).
- `flutter analyze` run directly this pass: **no issues found**.
- Not verified this pass: no live/device exercise of the "Add Father/Mother
  → Link Existing" flow itself — verification here is unit-test-level only
  (pure-function tests against `wouldCreateAncestryCycle`), consistent with
  how the other pure relation guards in this file were verified. No
  database-level check exists or was added — see `04_current_risks.md`.

## Live-device bug-hunting round (Supabase connected live, most recent round)
- Three crashes reproduced and confirmed fixed on a real Android device in
  `lib/screens/family/family_tree_screen.dart`:
  - Single-node graphview crash (`'_elements.contains(element)'`) — reproduced
    by viewing the tree of a brand-new profile with no relations yet.
  - Identity-churn crash (`'element._lifecycleState ==
    _ElementLifecycle.inactive'`) — reproduced by backgrounding and resuming
    the app while on the tree screen.
  - Double-dispose crash (`'A TransformationController was used after being
    disposed'`) — caught by a new widget test
    (`test/screens/family/family_tree_screen_rebuild_test.dart`) that pumps
    `FamilyTreeScreen` and lets it unmount, not by manual device testing.
    **This fix was later found incomplete — the same error recurred live
    on-device. See the "Crash C / Finding #4" entry below for the real fix
    and how it was verified.**
- The single-node bypass was cross-checked by reading the actual
  `graphview-1.5.1` package source: confirmed the library only special-cases
  exactly `nodes.length == 1`, so no other small-tree threshold exists that
  the fix could be missing.
- The double-dispose fix was cross-checked by reading `graphview`'s own
  `_GraphViewState.dispose()` source (`graphview-1.5.1/lib/GraphView.dart`),
  confirming it already disposes any `TransformationController` passed in via
  `GraphViewController` — so `_FamilyTreeScreenState` must not dispose it a
  second time.
- Migration 003 (`spouse_relationships`, drops `spouse_id`, updated
  `get_ego_network`) confirmed applied to the live Supabase project
  indirectly: the tree screen's couple-unit rendering depends on it, and the
  above device testing hit no schema/RPC errors — only the three
  Flutter-lifecycle bugs above.
- `flutter test` re-run in this handoff pass: **67/67 pass**
  (`test/screens/family/family_tree_data_test.dart`,
  `family_tree_pedigree_test.dart`, `family_tree_screen_rebuild_test.dart`,
  `relation_guards_test.dart`, plus the default `test/widget_test.dart`).
- `flutter analyze` re-run in this handoff pass: **no issues found**.
- `flutter build apk --debug` and `flutter build web` reported as succeeding
  this round (not re-run during this documentation pass).
- Not verified this round: multi-spouse add/remove flow end-to-end on
  device, invite-code claim flow, duplicate father/mother/spouse guards on
  device, migration 004 (not yet applied, so its RLS policies can't be
  verified live yet).

## Crash C / Finding #4 — `TransformationController` lifecycle, `family_tree_screen.dart` (most recent round)
- Crash C (the same `'A TransformationController was used after being
  disposed'` error as the earlier "double-dispose crash" fix, recurring live
  on-device after that fix had already shipped) was root-caused by reading
  the **entire** `_GraphViewState` class from `graphview-1.5.1/lib/GraphView.dart`
  this time, not partial greps as before — confirming it disposes its
  `TransformationController` unconditionally on every Element unmount, not
  only when the tree screen itself is left.
- The real fix (`_GraphViewHost`, a dedicated `StatefulWidget` owning
  controller creation/disposal in its own `initState`/`dispose`) was verified
  by adding 5 widget tests to
  `test/screens/family/family_tree_screen_rebuild_test.dart` (1 → 6 tests in
  that file). Each of the 5 was confirmed to actually fail — not just pass
  trivially — by temporarily reintroducing the specific bug being tested,
  confirming the test failed, then reverting the bug back out before
  re-confirming the test passed with the real fix in place.
- Finding #4 (a silent, non-crashing correctness bug: the split-callback
  same-`setState` race that could null out `_graphController` while a
  healthy tree was still on screen) was found by an independent code-review
  agent specifically tasked with adversarially reviewing the Crash-C fix —
  not found via manual device testing. The reviewing agent confirmed the bug
  empirically by writing and running its own reproduction before the fix (the
  `onControllerCreated`/`onControllerDisposed` split plus an `identical()`
  check on the disposal side) was applied.
- A 6th test was added for finding #4, proven to fail without the
  `identical()` check and pass with it, using the same fail-first-then-fix
  methodology as the other 5. An existing test in the same file was also
  strengthened to assert that tapping zoom-in actually increases the
  `InteractiveViewer`'s transform scale, rather than only checking that no
  exception was thrown — the weaker assertion is exactly the kind of check
  that would not have caught finding #4.
- `flutter test` re-run for this documentation pass: **78/78 pass** (`flutter
  test` output, verified directly). This is up from 73 tests before this
  round (`family_tree_screen_rebuild_test.dart` alone grew from 1 to 6: 5 new
  + 1 strengthened). Other test files present in the suite —
  `test/models/spouse_link_test.dart`,
  `test/providers/auth_provider_password_test.dart`,
  `test/providers/family_provider_spouses_test.dart`,
  `test/screens/family/family_tree_data_test.dart`,
  `test/screens/family/family_tree_pedigree_test.dart`,
  `test/screens/family/relation_guards_test.dart`, and the default
  `test/widget_test.dart` — were not modified this round.
- `flutter analyze` re-run for this documentation pass: **no issues found**.
- Installed and running on a physical Android device (Motorola Edge 50
  Fusion). The project owner's live re-verification pass on-device was **in
  progress, not yet confirmed complete**, as of this documentation pass — do
  not treat the fixes as device-confirmed beyond what the widget tests above
  cover until that's explicitly confirmed.
- Not verified this round: anything outside `family_tree_screen.dart`'s
  controller-lifecycle area (multi-spouse, invite/claim, migration 004, and
  the other items already listed as open below remain open).

## Multi-spouse + graphview tree rework (prior round)
- `flutter analyze` was clean against the reworked Dart model (`spouse_id`
  removed, `SpouseLink` added), the graphview-based `family_tree_screen.dart`,
  the multi-spouse UI changes, and the UI polish pass (`AppSpacing`,
  `friendlyErrorMessage`, `SectionCard`).
- No device/emulator run and no automated test coverage were performed for
  that round — static analysis passing did not mean those flows worked at
  runtime. The live-device round above is what closed that gap for the tree
  screen specifically.

## Checks already completed in earlier sessions
- `flutter analyze` passed after the latest edits.
- `flutter build apk --debug` succeeded.
- A device install succeeded earlier in the session when a device was connected.
- A later install attempt failed because no device/emulator was connected.

## Things that were explicitly observed
- `flutter gen-l10n` respected `l10n.yaml` and ignored CLI overrides.
- Magic-link loading originally caused a global spinner because auth status was set to loading.
- Tree layout code was custom and sensitive to row width changes — replaced by
  the graphview-based rewrite, since verified end-to-end on a live device (see
  above).

## What still needs verification
- Confirm the project owner's live on-device re-verification of the Crash C /
  Finding #4 fixes (zoom buttons after loading-state swaps, after view-mode
  switches, and after toggling the siblings badge, on the Motorola Edge 50
  Fusion) actually completed and passed — in progress, not confirmed, as of
  this documentation pass. See `04_current_risks.md`.
- Apply migration 004 to the live Supabase project, then verify its
  `spouse_relationships` RLS tightening actually rejects the no-connection
  case it was written to close (blocking — see `05_next_steps.md`).
- Live test of multi-spouse add/remove and the spouse-child linking prompt's
  empty-other-parent-slot condition (not covered by this round's device
  testing).
- Live test of login magic-link UX after the status change.
- Live test of duplicate father/mother prevention and duplicate spouse-pair
  prevention on device (covered by `relation_guards_test.dart` at the unit
  level, not yet re-confirmed live this round).
- Live test of invite-code claim flow.
- A live/manual reproduction attempt for the data-entry-layer ancestry-cycle
  gap (see `04_current_risks.md`) — currently only reasoned about, not
  exercised on device, since there's no guard yet to test against.

## Suggested next validation sequence
1. Apply migration 004 in the Supabase SQL editor.
2. Verify the tightened `spouse_relationships` RLS policies reject a
   no-connection link/unlink attempt.
3. Exercise multi-spouse add/remove, login, and invite-code claim flows
   manually on an Android device.
4. Re-run `flutter analyze` and `flutter test` if any further edits are made.
