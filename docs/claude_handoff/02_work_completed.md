# Work Completed So Far

## Authentication and app bootstrap
- Flutter app bootstraps in `lib/main.dart`.
- Providers are wired through `MultiProvider`.
- Supabase and local storage initialize at startup.
- Deep links are initialized and listened to.
- Localization is enabled with English and Gujarati support.

## Login behavior
- Login screen supports password and magic-link entry paths.
- Magic-link sending now stays on the login screen and shows a snackbar instead of forcing a full-screen loading state.
- Forgot-password flow exists.

## Tree visualization
- Family tree uses a custom stack-based layout with custom paint lines.
- Ego-centric layout is implemented.
- Sibling display toggle exists.
- Node tapping refocuses the tree around the tapped member.
- Child positioning was corrected so children stay under the focus node instead of drifting toward the canvas center when siblings widen the layout.

## Invite and claim flow
- Invite code database migration exists.
- FamilyMember model includes `inviteCode`.
- SupabaseService supports invite-code generation, lookup, and claim.
- Signup can accept invite codes.
- Invite cards/sheets show codes and support copy/share.
- Invite flow still supports deep links, but the code-based claim path covers the unreachable-link case.

## Relationship integrity
- Duplicate father/mother/spouse relation prevention was added.
- Guards were strengthened by re-fetching latest member data before save.
- Spouse addition now prompts to link existing children to the new spouse when applicable.

## Localization
- New strings were added for invite code and spouse-child linking flows.
- English and Gujarati arb files were updated.
- Generated localization artifacts exist under `lib/l10n/`.

## Backend work
- `001_initial_schema.sql` defines the base schema, RLS, and core RPCs.
- `002_invite_code.sql` adds invite-code support and claim-by-code RPCs.
- `003_multiple_spouses.sql` replaces the one-to-one `spouse_id` column with a
  `spouse_relationships` many-to-many table (generated `pair_key` for
  order-independent dedup, RLS mirroring the `family_members` model), migrates
  existing `spouse_id` data into it, drops `spouse_id`, and updates
  `get_ego_network` to traverse the new table. **Not yet applied to the live
  Supabase project** — see `06_supabase_and_data_model.md` and
  `04_current_risks.md`.

## Multi-spouse support (remarriage)
- `FamilyMember.spouseId` removed from the Dart model; Hive field index 5
  retired, not reused. New `SpouseLink` class added.
- `add_family_member_screen.dart` and `member_detail_screen.dart` updated:
  adding a spouse is always available (not hidden after the first spouse),
  duplicate check is per-pair rather than "already has a spouse", guarded by a
  re-fetch-before-check stale-data guard. Spouses display as a list.
- New `FamilyProvider.removeSpouse` plus UI affordance (with confirmation) to
  remove a mistaken spousal link.
- The existing spouse-add-prompts-to-link-children behavior was preserved,
  including only offering children with an empty other-parent slot, so
  remarriage never silently overwrites an existing biological parent link.

## Ego-network fetch fix
- `FamilyProvider.loadEgoNetwork` previously called
  `SupabaseService.getAllFamilyMembers()` (whole-table fetch on every tree
  view) despite a proper `get_ego_network` RPC already existing unused. Now
  calls `SupabaseService.getEgoCentricNetwork(memberId)`, which calls the RPC.
- Local caching (`LocalStorageService`) reworked to be incremental (upserts
  visited neighborhoods) instead of wipe-and-replace.
- The explicit "Sync Data" settings action still does a whole-table bulk fetch
  — kept deliberately as a user-initiated offline-prep feature for
  low-connectivity use, not a regression of the fetch-fix above.

## Family tree screen rewrite
- `lib/screens/family/family_tree_screen.dart` no longer uses hand-rolled
  pixel-math positioning (row-centering + shift/clamp/expand, source of
  recurring child-node-drift bugs). Now built on the `graphview` package
  (`BuchheimWalkerAlgorithm`) — already a pubspec dependency, previously
  unused.
- Each person + their spouse(s) modeled as a single "couple-unit" node
  (graphview's tree algorithm is single-parent-per-node, so couple-units work
  around two-parents-converge-on-child and multi-spouse).
- Larger text/icons, labeled "unclaimed profile" indicator (was an unlabeled
  bare icon), explicit zoom in/out/reset buttons plus InteractiveViewer
  pan/zoom (no more FittedBox+InteractiveViewer double-scaling). Tapping a
  node to re-center now triggers a real `loadEgoNetwork` fetch, not an
  in-memory relabel.

## UI polish pass
- New `lib/theme/app_spacing.dart` (`AppSpacing` token set) wired into the
  theme, including button/icon-button minimum tap-target sizes.
- `friendlyErrorMessage()` helper in `lib/widgets/common_widgets.dart`
  replacing raw exception text (`e.toString()`) in user-facing snackbars.
- Shared `SectionCard` widget reducing duplicated Card/Padding/Column
  boilerplate, used in settings/profile-form/member-detail.

## Live-device bug-hunting round (Supabase connected live, real device testing)
Three real crashes found via manual testing on a live Android device, all in
`lib/screens/family/family_tree_screen.dart`:
- **Single-node graphview crash** (`'_elements.contains(element)'` Flutter
  assertion) — a brand-new profile with no relations yet produced a
  single-node, edge-less `Graph`, which `BuchheimWalkerAlgorithm` isn't built
  to lay out. Fixed by bypassing `GraphView.builder` for that case
  (`data.graph.nodes.length <= 1` in `_buildDefaultView`), rendering the lone
  unit directly via `Center`. A code-review pass confirmed, by reading the
  `graphview-1.5.1` package source, that the library only special-cases
  exactly `nodes.length == 1` — no other small-tree threshold exists, so this
  bypass closes the whole bug class.
- **Identity-churn crash on incidental rebuilds**
  (`'element._lifecycleState == _ElementLifecycle.inactive'` Flutter
  assertion, reproduced by simply backgrounding and resuming the app on the
  tree screen) — `_buildTreeData`/`buildTreeData` built a brand-new `Graph()`
  with brand-new `Node` instances on every widget rebuild, including rebuilds
  unrelated to family data (an unrelated Provider notifying), while
  `GraphView.builder`'s own Element persisted across those rebuilds. Fixed by
  caching the built Graph/Node objects in `_FamilyTreeScreenState`
  (`_buildTreeDataCached`), keyed on reference-equality of
  `FamilyProvider.egoNetwork`/`spouseLinks` plus focus id and
  sibling-visibility.
- **Double-dispose crash on navigating away from the tree screen**
  (`'A TransformationController was used after being disposed'`) — confirmed
  by reading `graphview`'s own `_GraphViewState.dispose()` source
  (`graphview-1.5.1/lib/GraphView.dart`) that it already disposes any
  `TransformationController` passed in via `GraphViewController`.
  `_FamilyTreeScreenState` was also disposing the same shared controller
  itself. Fixed by removing `_FamilyTreeScreenState`'s own `dispose()`
  override entirely — graphview owns disposal of any controller passed to it.
  Caught by a new widget test
  (`test/screens/family/family_tree_screen_rebuild_test.dart`), not by manual
  device testing. **This fix was later found incomplete — the same crash
  recurred live on-device. See "Family tree screen: `TransformationController`
  lifecycle case study" below for the full sequence and the real fix.**

Also fixed this round:
- Pedigree ancestor-chain walk (`_buildPedigreeView`'s inline loop) had no
  cycle guard — bad `father_id`/`mother_id` data (e.g. two members set as each
  other's ancestor) could hang the UI indefinitely (an ANR, not a clean
  crash). Extracted into a pure, tested top-level `buildPedigreeChain` (in
  `family_tree_screen.dart`) with a visited-ids cycle guard. The
  tree-rendering side is now safe; **no guard exists yet at the data-entry
  layer** — nothing stops a user from creating such a cycle in the first
  place (e.g. "Add Father" → "Link Existing" → picking one's own descendant).
  See `04_current_risks.md`.
- Search tab was a dead end: tapping a result called
  `FamilyProvider.setCenterMember(member)` (relabels the center without
  loading that member's actual ego network) behind a `// Navigate to tree
  view` comment that was never implemented — nothing visible happened on tap.
  Fixed in `lib/screens/home/home_screen.dart`: `_SearchTab` now takes an
  `onMemberSelected` callback that calls
  `FamilyProvider.loadEgoNetwork(member.id)` and switches the bottom-nav tab
  to Family Tree (index 1).
- RLS gap in `spouse_relationships` (found by code review, not live testing):
  the INSERT/DELETE policies from `003_multiple_spouses.sql` used OR across
  both sides of the pair, letting an authenticated user link/unlink a spousal
  record between two people they have no connection to, as long as either
  side happened to be an unclaimed placeholder (common in this app). Fixed in
  a new migration `supabase/migrations/004_fix_spouse_rls.sql` — **not yet
  applied to the live Supabase project**, see `04_current_risks.md` and
  `06_supabase_and_data_model.md`.
- Empty-name defensive gap: `member.firstNameEn.substring(0, 1)` (avatar
  initials, 8 call sites across `home_screen.dart`,
  `add_family_member_screen.dart`, `member_detail_screen.dart`) assumed a
  non-empty name; the DB schema only enforces `NOT NULL`, not non-empty.
  Added `FamilyMember.initial` getter (safe, falls back to `'?'`) in
  `lib/models/family_member.dart` and swapped all 8 call sites to use it.
- Test-only constructors added: `AuthProvider.forTesting(...)` and
  `SettingsProvider.forTesting()` (plus
  `SettingsProvider.debugNotifyForTesting()`) — both `@visibleForTesting`,
  letting widget tests construct these providers without a live Supabase
  connection or initialized Hive boxes. Not used by any production code path.

Test count went 38 → 67 across this session: a prior round added 28
(extracting `buildTreeData`/`buildPedigreeChain` as pure, tested functions —
`test/screens/family/family_tree_data_test.dart` and
`family_tree_pedigree_test.dart`), and this round added 1 more
(`test/screens/family/family_tree_screen_rebuild_test.dart`, the widget-level
regression test that caught the double-dispose crash above). All 67 pass.
`flutter analyze` is clean. `flutter build apk --debug` and `flutter build
web` both succeed.

## Family tree screen: `TransformationController` lifecycle case study (crash B fix superseded by crash C, plus finding #4)
The double-dispose crash above (`'A TransformationController was used after
being disposed'`) recurred live on-device **after** its first fix had
already shipped and been treated as complete. This section documents that
sequence in full, since the pattern — a partial understanding of a
third-party library's lifecycle contract leading to an incomplete fix,
twice — is the actual lesson to carry forward for this file. See
`04_current_risks.md` for the "HIGH RISK" framing this earns for future work
on `_GraphViewHost`.

- **Recurrence (same error as the earlier "double-dispose crash" fix).** The
  first fix (removing `_FamilyTreeScreenState`'s `dispose()` override) was
  reasoned about only partially: `graphview-1.5.1`'s `_GraphViewState` was
  read enough to confirm it disposes a passed-in `TransformationController`,
  but not enough to see *when*. On this pass the entire `_GraphViewState`
  class was read: it creates its `TransformationController` exactly once in
  `initState()`, has no `didUpdateWidget` to adopt a new one later, and
  unconditionally disposes it in `dispose()` on every Element unmount, for
  any reason — not just "the user left the tree screen." In
  `family_tree_screen.dart` that includes the `isLoading` branch swapping the
  whole subtree to a spinner and back (every re-center/refresh tap),
  Family↔Pedigree view-mode switching, and the single-node bypass. Any one of
  those unmount/remount cycles could hand the next `GraphView` instance an
  already-disposed controller if a controller were being reused across them
  — which is exactly what the first fix's surviving code path still did.
- **Real fix.** Controller ownership was moved out of
  `_FamilyTreeScreenState` entirely and into a new `_GraphViewHost`
  `StatefulWidget`. `_GraphViewHost`'s own `initState`/`dispose` — which
  Flutter guarantees run fresh on every mount regardless of cause — now
  create and release the `GraphViewController`/`TransformationController`.
  `_FamilyTreeScreenState` keeps only a nullable `GraphViewController?
  _graphController`, set/cleared via a callback from `_GraphViewHost`, and a
  separate, State-owned `_pedigreeTransformController` dedicated to the
  pedigree view's plain `InteractiveViewer` — no longer sharing a controller
  between the two views, which had been part of what made the original code
  fragile. 5 new widget tests were added to
  `test/screens/family/family_tree_screen_rebuild_test.dart` (1 → 6 tests in
  that file), each confirmed to actually fail — not just pass trivially — by
  temporarily reintroducing the specific bug, confirming the test failed,
  then reverting the bug back out.
- **Finding #4 (no crash — a silent correctness bug), found by an
  independent code-review agent specifically tasked with adversarially
  reviewing the crash-C fix, not found on-device.** The crash-C fix used one
  nullable `onControllerChanged` callback for both "controller created" and
  "controller disposed." Toggling the siblings badge (`_showSiblings`)
  changes `_GraphViewHost`'s `key` within a single `setState`, so Flutter
  mounts the NEW `_GraphViewHost` instance (calling the callback with the new
  controller) *before* the OLD instance's `dispose()` runs (calling the same
  callback with `null`) — the null write landed second and clobbered the new
  instance's valid controller. `_graphController` silently went `null` with a
  perfectly healthy tree still on screen: the explicit zoom-in/zoom-out/reset
  buttons stopped doing anything, with no exception thrown. The reviewing
  agent confirmed this empirically by writing and running a reproduction,
  then fixed it by splitting the single callback into
  `onControllerCreated`/`onControllerDisposed`, where the disposal side only
  clears `_graphController` if it is still `identical()` to the controller
  being disposed (i.e. nothing newer has already taken over). A 6th test was
  added to `family_tree_screen_rebuild_test.dart`, proven to fail without the
  `identical()` check and pass with it. An existing test in the same file was
  also strengthened to assert that tapping zoom-in actually increases the
  `InteractiveViewer`'s transform scale, not merely that no exception was
  thrown — the weaker assertion is exactly the kind of check that would
  **not** have caught finding #4.

Verified: `flutter analyze` clean; `flutter test` **78/78 passing** (up from
73 before this round — 5 new tests plus 1 strengthened test in
`family_tree_screen_rebuild_test.dart`). Installed and running on a physical
Android device (Motorola Edge 50 Fusion); the project owner's live
re-verification pass on-device was in progress as of this handoff, **not yet
confirmed complete**. See `08_verification_log.md`.

## Auth incident: duplicate-signup-on-existing-email + mandatory password setup
A real incident, not just a code-review finding: the project owner tested
email+password signup on an email that already had an account (created
earlier via magic-link login on a different device). Supabase's `signUp()`
API silently attached the new password to the EXISTING `auth.users` row and
returned a normal-looking successful session — a documented Supabase
anti-enumeration behavior, it does not cleanly error when an email already
exists. `AuthProvider.signUpWithEmail` (unlike `signInWithEmail`) never
called `_loadCurrentMemberProfile()`, so the app didn't know a profile
already existed, routed to `ProfileFormScreen(isCreatingProfile: true)`, and
the user was asked to create a profile again — confirmed by the project
owner. This created a **second `family_members` row for the same
`auth_user_id`**, which breaks `getCurrentUserProfile()` (`.maybeSingle()`
throws on >1 row match) for any future login on that account. **Data cleanup
for the affected account is in progress, not yet confirmed complete** — see
`04_current_risks.md`.

Fixes (`flutter analyze` clean, all 67 tests pass — no new automated tests
were added for this round, see below):
- `lib/services/supabase_service.dart` — `signUpWithEmail` now checks
  `response.user!.identities?.isEmpty` after calling `signUp()`; an empty
  list is Supabase's documented signal that no new identity was created
  (email already registered), and it now throws
  `AuthException('vanshavali_email_already_registered')` instead of
  returning a false-success. Also added `updatePassword(String newPassword)`
  (wraps `client.auth.updateUser(UserAttributes(password: ...))`).
- `lib/providers/auth_provider.dart` — `signUpWithEmail` now always calls
  `_loadCurrentMemberProfile()` (defense in depth, matching what
  `signInWithEmail` already did) before deciding this is a fresh signup, so a
  signup that resolves to an existing account is treated as a login to that
  account, never a duplicate-profile-creating fresh signup.
- `lib/widgets/common_widgets.dart` — `friendlyErrorMessage` now maps the
  `vanshavali_email_already_registered` marker to a specific message (new
  l10n key `errorEmailAlreadyRegistered`, both locales) instead of the
  generic "service failure" bucket.

## New feature: mandatory password setup for magic-link accounts
Per explicit project-owner decision: magic-link-only accounts (no password
ever set) must now set a password before they can use the app, via a
**non-skippable** screen — not an optional Settings item. Rationale: villages
/ low-tech users may end up needing password-based login on a shared/
different device without email access.
- `AuthProvider.hasPasswordSet` (getter) tracks whether
  `deep_details['has_password']` is `true` on the current profile. Supabase's
  client SDK doesn't expose "does this identity have a password" directly, so
  this is tracked by the app itself in the existing flexible `deep_details`
  jsonb column — **no schema migration needed**. Chosen over a dedicated
  `family_members` column to avoid a migration for what is arguably
  auth-state, not profile data; worth reconsidering if more auth-state flags
  accumulate later.
- `AuthProvider.setPassword(password)` calls `SupabaseService.updatePassword`,
  then sets `deep_details['has_password'] = true` via `updateProfile`.
- Self-healing: `signInWithEmail` sets `deep_details['has_password'] = true`
  automatically the first time it detects it's missing on a successful
  password sign-in (covers accounts that had a password before this tracking
  existed).
- `lib/screens/profile/profile_form_screen.dart` — a brand-new profile
  created right after `signUpWithEmail` gets `has_password: true` tagged at
  creation time (via `AuthProvider.authenticatedWithPassword`, a transient
  per-session flag). Editing an existing profile now also explicitly
  preserves `has_password` across the edit — previously the whole
  `deep_details` map was rebuilt from scratch on every save, which would have
  silently wiped this flag (or any other deep_details field) on every profile
  edit. Note: this preservation currently only covers `has_password`
  specifically, not `deep_details` generally.
- New `lib/screens/auth/set_password_screen.dart` —
  `PopScope(canPop: false)`, `automaticallyImplyLeading: false`, no skip
  button. Password + confirm password form, calls `AuthProvider.setPassword`.
- `lib/main.dart` (`AppNavigator`) — inserted between the "has profile" check
  and `HomeScreen`: `if (!authProvider.hasPasswordSet) return const
  SetPasswordScreen();`. This means **every existing magic-link-only
  account**, including pre-existing test accounts, will hit this mandatory
  screen on next login — intentional per the "non-skippable" decision, not a
  bug, but a real behavior change for accounts that predate this feature. See
  `04_current_risks.md`.
- New l10n keys added to both `app_en.arb`/`app_gu.arb`:
  `errorEmailAlreadyRegistered`, `setPasswordTitle`, `setPasswordDescription`,
  `setPasswordButton`, `passwordSetSuccess`.

No automated test coverage exists yet for `signUpWithEmail`'s
identities-empty check, `hasPasswordSet`, or `setPassword` — verification for
this round was `flutter analyze` (clean) and the full `flutter test` suite
(67/67 pass, same count as before — none of the 67 exercise this new code
path). See `05_next_steps.md`.

## Explicitly deferred by project-owner decision — not a gap
Phone number login was explicitly declined for now: real ongoing SMS-provider
costs conflict with this project's zero-cost requirement. This matches the
original CLAUDE.md brief, which already lists phone auth as an
if-budget-allows-later item, not a v1 requirement. Not an open task — recorded
here so a future session doesn't re-raise it as a missing feature.

## Ancestry-cycle guard added at data entry (closes previously-open gap)
New pure, tested guard function `wouldCreateAncestryCycle` in
`lib/screens/family/add_family_member_screen.dart` (alongside the existing
`blockedOneToOneRelation`/`isSpouseAlreadyLinked`/`childrenNeedingOtherParent`
pure guards) walks a candidate's ancestor chain (both `father_id` and
`mother_id` branches, via a `resolve` callback — wired to
`FamilyProvider.getMemberById` in production) looking for the target's id,
bounded by `maxVisited` (default 200) so a pre-existing, unrelated cycle in
already-bad data can't cause an infinite loop. Wired into `_saveMember` right
after the existing one-to-one cardinality guard: fires only when the relation
is father/mother AND "Link Existing" AND an existing member was selected — a
brand-new member can never already be anyone's descendant, so the create-new
path doesn't need this check.

New l10n key `ancestryCycleBlocked` added to both `lib/l10n/app_en.arb` and
`lib/l10n/app_gu.arb` (regenerated via `flutter gen-l10n`), shown via the
existing `showAppSnackBar(..., isError: true)` pattern when the guard fires.

9 new unit tests added to `test/screens/family/relation_guards_test.dart`:
self-reference, allowing an unrelated existing member, a direct cycle
(picking your own child as father), a multi-generation cycle (grandchild as
mother), a cycle reachable only through the maternal branch, a legitimate
non-cycle case (a sibling of a descendant), clean termination on a dead-end
ancestor chain, the `maxVisited` bound against a pre-existing cycle in
unrelated data, and a null-resolver-returns-null case. Test count is now
**87** (up from 78), all passing. `flutter analyze` is clean.

This closes the ancestry-cycle gap at the **app level only** — there is
still no database-level constraint against a cyclic father_id/mother_id
chain. This app-level guard, at this one entry point, is currently the only
thing preventing a cycle from being created through normal app usage; it
would not stop one created via direct API/SQL access bypassing the app. It
is a separate, complementary fix to the tree-*rendering* cycle guard
(`buildPedigreeChain`'s visited-ids guard, added in an earlier round — see
"Family tree screen rewrite" above) — that guard only prevents the UI from
hanging on a cycle that already exists, it does not prevent a cycle from
being created. See `04_current_risks.md` and `06_supabase_and_data_model.md`.

## Open product question — not resolved, needs a decision
Pedigree View is functionally capped at ~1 ancestor generation beyond the
focus member, because `get_ego_network` (both 001+003 migrations) only ever
returns center + parents + children + spouse + siblings — never
grandparents — per the project's mandatory ego-centric-fetch requirement
(CLAUDE.md §4B). This may be intentional (matches the "never fetch the whole
village" constraint) or may need a dedicated ancestor-chain RPC if deeper
pedigree views are actually wanted. See `05_next_steps.md`.
