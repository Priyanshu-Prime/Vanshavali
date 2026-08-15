# Current Risks and Things That Could Go Wrong

## ACTION NEEDED — migration 005 (get_ancestor_chain RPC) not yet applied to live DB
`supabase/migrations/005_ancestor_chain.sql` exists on disk but, like 004
before it, has **not** been run against the live Supabase project — DB
programmatic access is still broken by the Supavisor pooler bug (see
`06_supabase_and_data_model.md`), so this needs the project owner to paste it
into the Supabase SQL Editor manually. Until then, the Pedigree view fix
below silently falls back to showing only one generation (same as before the
fix) rather than erroring — worth confirming this was actually applied
before assuming the pedigree fix works live.

## Fixed this round — live-device follow-up (found via direct on-device testing after the frontend sweep below)
Several more real bugs/design gaps found live on-device (Motorola Edge 50 Fusion) right after the frontend sweep. All covered by widget/unit tests (91 tests total, up from 87; the testable ones verified via deliberate bug-reintroduction — reverted the fix, confirmed the new test failed for the right reason, then restored it — same methodology as the graphview crash fixes). Test suite: 91 tests.

- **Re-center tap replayed a full "tree builds itself" animation every single time, feeling sluggish/not seamless.** Root cause: `_GraphViewHost` fully remounts on every re-center (a deliberate design from the Crash C/Finding #4 fix — new key each time). `graphview`'s `GraphView.builder` defaults `animated: true`, which — confirmed by reading `RenderCustomLayoutBox._updateVisibleNodeAnimation`/`_updateAnimationStates` in the package source — replays a per-node "fly in from parent position" animation *every time its RenderObject is freshly created*, i.e. every tap, not just first load. The package's own `hitTestChildren` also ignores taps while that animation plays, compounding the sluggish feel. Fixed by passing `animated: false` explicitly — this app never used graphview's collapse/expand feature the animation exists for, so there's no functional loss.
- **Pedigree view rebuilt entirely** (superseding an initial, smaller fix attempt) after live feedback: it only ever showed the paternal line (never mothers), and the line between generations visually landed between a person and their spouse rather than on a specific parent/child. Root cause of the "no mothers" part: the *original* fix (fetching a deeper ancestor set — see the ACTION NEEDED item above) still fed the result into `buildPedigreeChain`, a single-line "father, or mother-then-father" chain walker with a Paternal/Maternal toggle — not a real two-parent-per-generation pedigree chart. **Replaced entirely**: `buildPedigreeChain` and the Paternal/Maternal toggle are gone; `buildPedigreeAhnentafel` now builds the standard ahnentafel (Sosa-Stradonitz) numbering (index 1 = focus, `2n`/`2n+1` = father/mother of index `n`), and `_buildPedigreeView` renders it as absolutely-positioned `_PersonBox`es (no couple-unit merging — every ancestor is their own box) with a new `_PedigreeConnectorPainter` drawing proper T-junction/elbow connectors from each specific parent to their specific child. Confirmed with the project owner via an ASCII preview before building. `test/screens/family/family_tree_pedigree_test.dart` was fully rewritten (old file deleted, new one covers the ahnentafel math + missing-data + maxGenerations + cycle-safety cases — cycle safety is now structural: the walk is a fixed-count `for` loop over generations, not an unbounded chain, so it can't hang even on bad data, unlike the guard the old version needed).
- **Default tree view: same underlying complaint (lines not landing on the right person) fixed too, without restructuring couple-units.** graphview's `TreeEdgeRenderer` already draws clean L-shaped connectors by default, but anchors them to the *geometric center* of each node's bounding box — for a couple-unit (person + spouse, wider than a single person), that center sits between the two partners, not on the blood relative continuing the line. Every node this tree renders (`_PersonBox`, `_SiblingsBadge`) is a fixed 136px box always drawn first/leftmost within its unit, so a new `_FamilyTreeEdgeRenderer` (subclasses `TreeEdgeRenderer`, overrides `buildTopBottomPath`) anchors to a fixed 68px offset from each node's left edge instead of the true center — no couple-unit restructuring needed, no risk of reintroducing the "graphview can't express two parents converging on one child" problem that couple-units were adopted to solve in the first place.
- **General visual polish pass** on both views per an explicit "looks old-school" complaint: rounded stroke caps/joins on connector lines (was: sharp mitered corners), soft drop shadows + a gradient fill + a circular avatar-style icon badge on `_PersonBox`/`_SiblingsBadge` (was: flat fill, bare icon), and a small heart-in-circle marriage marker replacing the plain bar in `_MarriageConnector`. Gender-based box-vs-oval shape convention (CLAUDE.md) is untouched.

**Testability caveat**: the default-view edge-anchor fix (`_FamilyTreeEdgeRenderer`) and the visual polish have no dedicated automated test — both are canvas/paint-level changes that would need golden-image testing, which isn't set up in this project (same category of gap already noted elsewhere in this file). Verified via `flutter analyze` + the full test suite passing, and will need the project owner's live-device confirmation.

## Fixed this round — frontend correctness/UX sweep (two independent read-only audits + direct fixes, no widget-test coverage added — see caveat below)
The DB-password/Supavisor pooler bug (separate, still open — see `06_supabase_and_data_model.md`) blocked further backend work, so this round pivoted to a full frontend sweep: a `vanshavali-ux-auditor` pass and an independent `vanshavali-reviewer` correctness pass across all of `lib/`, then direct fixes for everything CRITICAL/HIGH/SEVERE found. A third agent (`vanshavali-test-engineer`, tasked with adding widget-test coverage for the previously-untested auth/profile/settings/add-member screens) **failed mid-run on a session API rate limit and produced nothing** — that coverage gap is still open, see `05_next_steps.md`. Everything below was fixed directly, verified only via `flutter analyze` (clean) + the existing test suite (87/87 passing, unchanged count — none of these fixes have their own regression test yet, see caveat below).

- **CRITICAL — flaky "online" network state could silently duplicate a returning user's profile.** `AuthProvider._loadCurrentMemberProfile()` trusted `connectivity_plus`'s "online" signal, not whether the actual Supabase fetch succeeded. On a timeout/DNS blip (routine on this app's target rural network conditions), the catch block recorded `_error` but left `_currentMember` null with no fallback to the local Hive cache — unlike the genuinely-offline branch, which does fall back. A returning user hitting this got routed into "Complete Your Profile," and saving that form created a **second `family_members` row** — the same failure class as the OPEN duplicate-profile incident below, but via a different trigger. Fixed: the online path now falls back to the local cache on a thrown exception (not on a legitimate empty result), mirroring the offline branch.
- **CRITICAL — claiming an invite during signup left `has_password` untagged, wrongly triggering the mandatory set-password screen right after the user had just set one.** `claimProfile`/`claimProfileByCode` only ever set `auth_user_id`; the only two places that tag `deep_details['has_password']` are `ProfileFormScreen` (skipped entirely when an invite claim means `hasProfile` is already true) and the self-heal already present in `signInWithEmail`. `signUpWithEmail` had no equivalent self-heal. Fixed: added the same self-heal to `signUpWithEmail`, run after the claim so it sees the claimed profile.
- **SEVERE — `SetPasswordScreen` had no offline path and no way out, risking a full app lockout.** `setPassword()` is a live, unqueued Supabase Auth call (no offline sync queue, unlike data edits). The screen is deliberately `PopScope(canPop: false)` with no skip option. A user with a persisted session but `hasPasswordSet == false` who reopens the app offline (session + cached profile both load fine from local storage) would be stuck on this screen with literally no way out until they got connectivity. **This is a product-behavior change I made under this round's "fix and report" autonomy given the severity (total lockout), not a pure bug fix — flagging it explicitly rather than burying it in the list**: added a "Logout" text button (same `showConfirmDialog` pattern as Settings' logout) so the user can at least exit instead of being trapped. The mandatory-password requirement itself is untouched — there is still no way to reach `HomeScreen` without setting one, only a way to back out of the session entirely.
- **HIGH — Family Tree screen and Home dashboard swallowed fetch errors, showing a misleading "no family yet" empty state instead of an error.** Neither checked `familyProvider.error`, unlike the Search tab (which already does this correctly with a retry button). Fixed both to show an error state (tree screen: full `AppWidgets.error` with retry; dashboard: an inline error banner above the family cards, since the profile card etc. should stay usable) only when there's no cached data to fall back on.
- **HIGH — `AddFamilyMemberScreen._saveMember` could report full success while a relation link silently failed.** `FamilyProvider.linkFamilyMember`/`createFamilyMember` catch their own exceptions and return `false`/`null` rather than throwing, so most call sites in `_saveMember` ignored the return value entirely — e.g. creating a child, linking it to the primary parent, but silently failing to link the explicitly-chosen "other parent," while still showing "Family member added successfully." Fixed: every link/create call in the primary path now checks its result and throws on failure (caught by the existing try/catch, surfaced via the existing `friendlyErrorMessage` snackbar). The one exception is the *bulk* "link existing children to new spouse" loop, which is best-effort by design (the primary spouse-add already succeeded) — a failure there now sets a flag that swaps the success message for a new `familyMemberAddedPartial` l10n string instead of aborting/throwing.
- **MEDIUM — `fullSync()` cleared the local offline cache *before* re-fetching, and nothing in the call chain caught a failure.** A connection drop mid-sync (plausible for this audience) left the user with an empty cache and no error shown — silently destroying the "browse anywhere in the village without a connection" data the feature exists to provide. Fixed: `LocalStorageService.fullSync()` now fetches both tables first and only clears+replaces the cache after both succeed; `settings_screen.dart`'s full-sync button now wraps the call in try/catch with a `friendlyErrorMessage` error snackbar.
- **MEDIUM — the Father/Mother/Spouse/Child/Sibling `ChoiceChip` picker was the one interactive control that missed the app's own 48dp touch-target standard.** Every button/icon-button theme enforces `AppSpacing.minTapTarget`; chips had no `chipTheme` at all (Material default ~32-40dp). Added a `chipTheme` (light + dark) with padding sized to clear the 48dp floor.
- **LOW — "Link Existing" member search showed nothing on zero results**, unlike the Home tab's search (which correctly shows an empty state). Fixed with the same `AppWidgets.empty` pattern, gated on the query actually having ≥2 characters (so it doesn't show before a search is attempted).
- **LOW — one ad hoc color fixed for in-file consistency**: `member_detail_screen.dart`'s delete-confirmation dialog used raw `Colors.red` while the remove-relation button two lines away (same file) already used `Theme.of(context).colorScheme.error`. Made consistent. Other ad hoc `Colors.green`/`Colors.orange` usages (verified/claimed badges, sync-status icons) found across several screens were left alone — decorative status indicators, not confirmed contrast/consistency bugs, and fixing all of them is a wider mechanical sweep better done as its own pass if wanted.
- **Minor cleanup**: removed a verbatim-duplicated doc-comment block in `family_tree_screen.dart` (leftover from the Finding #4 fix, see below) and an unused `DeepLinkHandler` widget in `deep_link_service.dart` (dead code — `main.dart`'s `AppNavigator` reimplements the same logic inline instead; confirmed zero references anywhere else in `lib/`). Also added two missing `notifyListeners()` calls on `AuthProvider.signInWithMagicLink`/`resetPassword`'s success paths (present on every other method in the file; harmless today since no call site uses `context.watch` around them, but an inconsistency that would silently break a future reactive listener).

**Not fixed, flagged as product/design decisions rather than autonomously changed:**
- No in-app legend explaining the tree's box=male/oval=female/grey=unclaimed convention — implemented correctly but never explained on-screen, a real first-time-user usability gap.
- "View Profile"/"Add Family Member"/"Invite" from the tree are reachable only via long-press on a node, with no visual affordance hinting the menu exists — low discoverability for a low-tech-literacy audience.
- Both of the above would change the tree screen's visual design, not just fix a defect, so they weren't done without sign-off — see `05_next_steps.md`.

**Testability caveat — none of the fixes above have a dedicated regression test.** Every one touches code paths coupled to the static `SupabaseService`/`SyncService` classes (`AuthProvider._loadCurrentMemberProfile`, `linkFamilyMember`/`createFamilyMember` failure paths, `LocalStorageService.fullSync`), which this project's test infrastructure can't reach without live Supabase or a mocking library — no `mockito`/`mocktail` dependency exists yet (see `pubspec.yaml`). This is a pre-existing gap, not new: the existing `AuthProvider.forTesting()` seam explicitly bypasses `_init()`/`_loadCurrentMemberProfile()` for the same reason (see its doc comment). Verified only via `flutter analyze` (clean) and the existing 87-test suite (unchanged, all still passing) — **these fixes have not been exercised on a live device or with a mocked failure injected**, only reasoned through by reading the code paths directly.

## OPEN — duplicate `family_members` row for priyanshumakwana920@gmail.com, cleanup NOT confirmed complete
A real incident: signing up with email+password on an email that already had
an account (from a prior magic-link login) caused Supabase's `signUp()` to
silently attach the new password to the EXISTING `auth.users` row (documented
anti-enumeration behavior), and — before this round's fix — the app didn't
detect that and created a **second `family_members` row for the same
`auth_user_id`**. This breaks `getCurrentUserProfile()` (`.maybeSingle()`
throws on >1 row match) for future logins on that account. The bug that
caused this is now fixed (see `02_work_completed.md`), but the **existing
duplicate data has not been confirmed cleaned up**. The project owner was
given a read-only diagnostic SQL query in a scratchpad file (not committed to
the repo) to inspect the duplicate rows before deciding what to delete/merge.
Treat this as still-open until explicitly confirmed resolved — do not assume
the affected account works correctly.

## BEHAVIOR CHANGE — mandatory set-password screen now blocks ALL existing magic-link accounts
New this round: any authenticated account whose profile's
`deep_details['has_password']` is not `true` is routed to a non-skippable
`SetPasswordScreen` (`lib/main.dart`'s `AppNavigator`, before `HomeScreen`) on
next login. This includes **every pre-existing magic-link-only account**,
not just new signups going forward — there is no grandfathering. This is
intentional per explicit project-owner decision (villages/low-tech users may
need password login on a shared/different device), not a bug, but worth
flagging loudly since it changes login behavior for accounts nobody
retroactively opted into this. See `02_work_completed.md` for full detail.

## BLOCKER — migration 004 not applied
`supabase/migrations/004_fix_spouse_rls.sql` (tightens the
`spouse_relationships` INSERT/DELETE RLS policies added by 003) exists on disk
but has **not** been run against the live Supabase project. Until a human
applies it via the Supabase SQL editor (same process as 001-003), the live
database still runs the looser 003 policies: an authenticated user can
link/unlink a spousal record between two people they have no connection to,
as long as either side happens to be an unclaimed placeholder (common in this
app). This is the current top blocker before spouse-relationship RLS can be
considered correct in production. See `06_supabase_and_data_model.md` and
`05_next_steps.md`.

## Resolved at app level — ancestry-cycle prevention added at data entry
~~Nothing in the UI or database currently prevents a user from creating a
father_id/mother_id cycle in the first place~~ — a new pure, tested guard,
`wouldCreateAncestryCycle` (`add_family_member_screen.dart`, alongside the
existing `blockedOneToOneRelation`/`isSpouseAlreadyLinked`/
`childrenNeedingOtherParent` guards), now blocks this at the one place a
cycle could actually be created through the app: "Add Father"/"Add Mother" →
"Link Existing" → picking an existing member. It walks the candidate's
ancestor chain (both `father_id` and `mother_id` branches) via
`FamilyProvider.getMemberById`, bounded by `maxVisited` (200) so a
pre-existing, unrelated cycle in already-bad data can't turn the check into
an infinite loop. Wired into `_saveMember` right after the existing
father/mother cardinality guard; only fires for "link existing" father/mother
(a brand-new member can never already be anyone's descendant). New l10n key
`ancestryCycleBlocked` (both locales). 9 new tests in
`test/screens/family/relation_guards_test.dart` (suite now 87, up from 78,
all passing); `flutter analyze` clean. See `02_work_completed.md`.

**This closes the gap at the app level only.** There is still **no
database-level constraint** against a cyclic `father_id`/`mother_id` chain —
nothing in the schema or RLS policies stops one. This app-level guard, at
this one entry point, is currently the ONLY thing preventing a cycle from
being created through normal app usage; it would not stop a cycle created via
direct API/SQL access that bypasses the app. See `06_supabase_and_data_model.md`.

This is a separate, complementary fix to the tree-*rendering* cycle guard
added in an earlier round (`buildPedigreeChain`'s visited-ids guard in
`family_tree_screen.dart`, see "Fixed since last handoff" below) — that one
only stops the UI from hanging on a cycle that already exists, it does not
stop a cycle from being created. These are two separate guards, not the same
fix twice: one covers rendering-safety for data that's already bad, the
other covers creation-prevention going forward at the app layer.

## Resolved — migration 003 is now applied
~~migration 003 not applied~~ — `003_multiple_spouses.sql` has been applied to
the live Supabase project since the last handoff. Confirmed indirectly: a
round of manual testing on a live Android device exercised the tree screen
end-to-end — every couple-unit node it renders reads `spouse_relationships`
via `get_ego_network` — without hitting any schema/RPC errors. The three
crashes found this round (below) were Flutter framework/widget-lifecycle
bugs, not database errors. Focused add/remove-spouse flow testing (dedupe,
spouse-child linking prompt) on device is still open — see "High-risk areas"
below.

## Fixed — live-device crashes in family_tree_screen.dart (case study; see HIGH RISK note below)
Four issues were found in this file across two rounds, all rooted in the
same underlying cause: incomplete understanding of `graphview`'s
`_GraphViewState` controller-lifecycle contract. Full narrative in
`02_work_completed.md`; how each was confirmed in `08_verification_log.md`.

- **Crash A — single-node graphview crash** on a brand-new profile with no
  relations (`'_elements.contains(element)'` assertion) — a single-node,
  edge-less `Graph` can't be laid out by `BuchheimWalkerAlgorithm`. Fixed by
  bypassing `GraphView.builder` for the `nodes.length <= 1` case in
  `_buildDefaultView`. Not part of the controller-lifecycle pattern below;
  confirmed fixed and not revisited.
- **Identity-churn crash on incidental rebuilds**, reproduced by
  backgrounding/resuming the app on the tree screen
  (`'element._lifecycleState == _ElementLifecycle.inactive'`) — the built
  `Graph`/`Node` objects are now cached (`_buildTreeDataCached`) instead of
  rebuilt on every widget rebuild. Also not part of the pattern below;
  confirmed fixed and not revisited.
- **Crash B — `TransformationController` double-dispose, first fix
  (INCOMPLETE — superseded by Crash C below).** `_FamilyTreeScreenState`'s
  own `dispose()` was disposing a `TransformationController` that
  `graphview`'s own `_GraphViewState.dispose()` also disposes (confirmed at
  the time by reading `graphview-1.5.1/lib/GraphView.dart`, but only
  partially). The fix shipped — removing `_FamilyTreeScreenState`'s
  `dispose()` override — was believed complete but only covered the
  narrowest trigger, leaving the screen entirely.
- **Crash C — the SAME `'A TransformationController was used after being
  disposed'` error, again, live on-device, after Crash B's fix was already
  shipped and believed complete.** This time the *entire* `_GraphViewState`
  class was read (not partial greps): it sets its `TransformationController`
  exactly once in `initState()`, has no `didUpdateWidget` to pick up a new
  one later, and unconditionally disposes it in `dispose()` — every time its
  Element unmounts, for **any** reason. That is far broader than "leaving the
  screen": this screen's `isLoading` branch swaps the whole subtree to a
  spinner and back on every re-center/refresh tap, Family↔Pedigree view-mode
  switching unmounts/remounts it, and the single-node bypass (Crash A) does
  too — none of which Crash B's fix accounted for.
  **Real fix**: controller ownership moved into a new `_GraphViewHost`
  `StatefulWidget` whose own `initState`/`dispose` — which Flutter guarantees
  run fresh on every mount, regardless of cause — create and release the
  `GraphViewController`/`TransformationController`, instead of
  `_FamilyTreeScreenState` trying to track when a shared one might be stale.
  `_FamilyTreeScreenState` now holds a nullable `GraphViewController?
  _graphController` (set/cleared via callback) plus a **separate**,
  State-owned `_pedigreeTransformController` for the pedigree view's plain
  `InteractiveViewer` — never shared with graphview's controller, which was
  part of what made this fragile. 5 widget tests were added to
  `test/screens/family/family_tree_screen_rebuild_test.dart` (the file grew
  from 1 test to 6), each verified to actually fail — not just pass trivially
  — by temporarily reintroducing the specific bug, confirming the test
  failed, then reverting.
- **Finding #4 — silent correctness bug, found by an independent code-review
  agent adversarially reviewing Crash C's fix, NOT found on-device.** Crash
  C's fix used a single nullable `onControllerChanged` callback. Toggling the
  siblings badge (`_showSiblings`) changes `_GraphViewHost`'s key *within one
  `setState`*, so Flutter mounts the NEW `_GraphViewHost` (registering its
  controller) *before* the OLD instance's `dispose()` runs (which called the
  same callback with `null`) — the null write landed second and clobbered the
  new instance's still-valid controller. Result: `_graphController` silently
  went `null` with a perfectly healthy tree still on screen — the explicit
  zoom-in/zoom-out/reset buttons silently stopped working, with no exception
  thrown. Confirmed empirically: the reviewing agent wrote and ran a
  reproduction. Fixed by splitting the callback into
  `onControllerCreated`/`onControllerDisposed`, where the disposal side only
  clears `_graphController` if it is still `identical()` to the controller
  being disposed (i.e. nothing newer already took over). A 6th test was
  added, proven to fail without the `identical()` check and pass with it. An
  existing test was also strengthened to assert the zoom button actually
  changes the transform scale, not just "no exception was thrown" — the
  weaker check is exactly the kind of assertion that would **not** have
  caught this finding.

## HIGH RISK — this file's graphview controller lifecycle has now had two fixes independently found incomplete
Crash B's fix (removing `_FamilyTreeScreenState.dispose()`) was believed
complete and shipped, then found insufficient when the same crash recurred
live on-device (Crash C). Crash C's own fix was then independently reviewed
and found to have a separate, silent bug (Finding #4). This is the second
time in a row a change to this specific area looked complete and wasn't. Any
**future** change to `_GraphViewHost`, `_pedigreeTransformController`, or the
`onControllerCreated`/`onControllerDisposed` wiring should be treated as
high-risk and get the same treatment that finally worked here — read the
*entire* relevant `graphview` source (not a partial grep), write a test, and
prove the test actually fails without the fix — not a quick patch assumed
correct just because `flutter analyze`/`flutter test` pass.

## High-risk areas
- Relationship linking is stateful and touches both local storage and Supabase, so stale data can create duplicates if not re-fetched before save.
- The custom invite-link flow depends on platform deep-link support; unreachable links are still a practical risk for uninstalled or misconfigured cases.
- Magic-link flow should never route the user to a spinner screen unless an actual auth session check is happening.
- Spouse-child linking needs careful testing to avoid incorrectly linking children or asking at the wrong time — critical that it only offers children with an empty other-parent slot, so remarriage never silently overwrites an existing biological parent link.
- Multi-spouse UI (`add_family_member_screen.dart`, `member_detail_screen.dart`) has not had a focused live-device pass yet — this round's device testing centered on the tree-screen crashes above, not multi-spouse add/remove. Dedupe relies on the `pair_key` unique constraint plus a re-fetch-before-check guard in the app; both still need dedicated device verification.
- The search tab was a dead end until this round's fix (tapping a result did nothing visible) — worth spot-checking other list/tap flows in the app for the same "handler exists but does nothing" pattern, since it went unnoticed until now.
- The `signUpWithEmail`-on-existing-email fix and the new mandatory set-password flow (`hasPasswordSet`, `setPassword`, `SetPasswordScreen`) have **no automated test coverage** and have not been manually re-verified live post-fix — only `flutter analyze`/`flutter test` (67/67, unchanged count) back them. See `02_work_completed.md` and `05_next_steps.md`.
- `errorEmailAlreadyRegistered`'s copy (both `app_en.arb` and `app_gu.arb`) says the user "can set a password from Settings after logging in" — this is inaccurate now: there is no Settings entry point for this, only the mandatory `SetPasswordScreen` that appears automatically. Low-impact (the message still correctly tells the user to log in instead), but worth fixing the wording if this string is touched again.

## Fixed after code review of the multi-spouse round (verified via flutter analyze + flutter test, 67/67 passing; device verification of the multi-spouse-*specific* flows themselves, as opposed to general tree rendering, is still open — see "High-risk areas" above)
- `MemberDetailScreen`/`AddFamilyMemberScreen` reached via "View Profile" (not "Center on this member") previously left `FamilyProvider.egoNetwork` scoped to whoever was centered before, not the member actually being viewed/edited — this could cause the spouse-add children-linking prompt to silently see zero children (reading the wrong person's network) and never fire. Both screens now call `loadEgoNetwork(member.id)` on open to guarantee correct scope.
- `FamilyProvider.linkFamilyMember` (father/mother/spouse/child/sibling) previously did not queue a pending-sync entry when offline, unlike create/update/delete — a relation added while offline was silently lost the next time the network re-synced. Now queued via a new `'link'` pending-sync action, replayed in `LocalStorageService._pushPendingChanges`.
- `FamilyProvider.spousesInNetwork` lacked the co-parent-inference fallback that `spouse`/`getSpousesOf` had (a shared child's other parent counts as a spouse even with no explicit `spouse_relationships` link, for legacy/incomplete data) — consolidated so all three now share one implementation.
- Two `IconButton`s (invite-code copy in the tree screen's invite sheet, tree-screen refresh) and three in `member_detail_screen.dart` (edit/share/delete) had no `tooltip`; added using existing l10n keys. `SizedBox(height: 44)` wrappers around the invite-link copy/share buttons in both screens overrode the theme's 48dp minimum tap-target floor — removed so they inherit the theme default.

## Fixed since last handoff (verified how)
- ~~Family tree layout can regress easily because node positions, row widths,
  and connector lines are tightly coupled~~ — the hand-rolled pixel-math
  layout (row-centering + shift/clamp/expand) was replaced with the
  `graphview` package (`BuchheimWalkerAlgorithm`) in
  `lib/screens/family/family_tree_screen.dart`. Now verified on a live
  Android device (see "Fixed this round" above) — the bugs found there were
  graphview/Flutter-lifecycle integration bugs, not layout-math bugs, and are
  now fixed.
- ~~`loadEgoNetwork` fetches the whole village~~ — `FamilyProvider.loadEgoNetwork`
  previously called `SupabaseService.getAllFamilyMembers()`, fetching the
  entire `family_members` table on every tree view despite a proper
  `get_ego_network` RPC already existing unused. Now calls
  `SupabaseService.getEgoCentricNetwork(memberId)`, which calls the RPC.
  The explicit "Sync Data" settings button intentionally still does a
  whole-table fetch — that's a deliberate, user-initiated offline-prep
  feature, not a regression.

## Known technical cautions
- `main.dart` currently shows a loading screen while auth status is `initial` or `loading`. Any auth function that sets `loading` will trigger that global spinner.
- Child, sibling, father, mother relation rules should be treated differently from spouse. Father/mother are one-to-one; spouse is many-to-many (post-003); child/sibling are not one-to-one either.
- `FamilyProvider` loads the ego network from Supabase or local storage depending on connectivity, so offline fallback paths still matter. Local caching is now incremental (upserts visited neighborhoods) rather than wipe-and-replace — worth confirming this doesn't leave stale cached members behind after a relation is removed.
- Localization files are generated; manual edits to generated localization code should be avoided.
- `family_tree_screen.dart`'s `_buildTreeDataCached` cache is keyed on
  reference-equality of `FamilyProvider.egoNetwork`/`spouseLinks`. Any future
  change to `FamilyProvider` that mutates those lists in place (instead of
  assigning a new list on every re-fetch) would silently break cache
  invalidation and reintroduce the identity-churn crash class fixed this
  round — keep relation-loading code assigning new lists, not mutating.

## Data-model cautions
- Supabase schema and Dart model must stay in sync — 001-003 are in sync and
  confirmed applied live (see above); **004 is not yet applied**, see the
  blocker above.
- Hive field numbers must never be reused. Field index 5 (`spouseId`) is
  retired and must stay retired.
- Any change to relationship logic should consider both server persistence and offline cache behavior.
- An app-level guard now exists at the data-entry layer against ancestry
  cycles (`wouldCreateAncestryCycle` in `add_family_member_screen.dart`) —
  see "Resolved at app level" above. No database-level constraint exists
  yet — a cycle could still be created via direct API/SQL access that
  bypasses the app.
- `deep_details['has_password']` is an app-managed flag, not a schema column
  (no migration) — see `06_supabase_and_data_model.md`. `ProfileFormScreen`'s
  profile-edit save path only explicitly preserves this one `deep_details`
  key across a rebuild-from-scratch save; any other future `deep_details`
  field would be silently wiped the same way `has_password` almost was —
  worth generalizing the preservation logic if more flags are added.
- The known duplicate-`family_members`-row incident (see the "OPEN" section
  at the top of this file) is a live demonstration that
  `getCurrentUserProfile()`'s `.maybeSingle()` throws on >1 row match for a
  given `auth_user_id` — there is still no database constraint preventing a
  second row with the same `auth_user_id` from being created again the same
  way if a similar auth-flow bug is reintroduced.

## Verification caution
- This round's live-device testing covered the tree screen specifically
  (new-profile, app-resume, leave-screen) and confirmed migration 003 is live
  and working. It did not cover multi-spouse add/remove, the invite/claim
  flow, or duplicate-relation guards end-to-end on device — those still need
  a pass, see `05_next_steps.md`.
- Automated test coverage now exists beyond the default scaffold:
  `test/screens/family/family_tree_data_test.dart`,
  `family_tree_pedigree_test.dart`, `family_tree_screen_rebuild_test.dart`,
  and `relation_guards_test.dart`, plus `test/models/spouse_link_test.dart`,
  `test/providers/auth_provider_password_test.dart`, and
  `test/providers/family_provider_spouses_test.dart` — **87 tests total, all
  passing** (`flutter analyze` clean) as of this handoff (78 + 9 ancestry-cycle
  guard tests from the round that added `wouldCreateAncestryCycle`, see
  "Resolved at app level" above). The Crash
  C/Finding #4 round (see above) added 5 tests and strengthened 1 existing
  one in `family_tree_screen_rebuild_test.dart` alone (1 → 6 tests in that
  file), bringing the suite from 73 to 78.
- The Crash C / Finding #4 fixes were installed and run on a physical Android
  device (Motorola Edge 50 Fusion). The project owner's live re-verification
  pass on-device was in progress as of this handoff — **not yet confirmed
  complete**. Do not assume the fixes are device-verified beyond the
  automated widget tests until that's confirmed.
