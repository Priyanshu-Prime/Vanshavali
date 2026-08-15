# Key File Touchpoints

## App entry and routing
- `lib/main.dart` - app bootstrap, localization, provider setup, auth
  routing, deep-link initialization. `AppNavigator` now inserts a mandatory,
  non-skippable `SetPasswordScreen` between the "has profile" check and
  `HomeScreen` whenever `!authProvider.hasPasswordSet` — applies to every
  authenticated account, including pre-existing magic-link-only ones. See
  `04_current_risks.md`.

## Authentication
- `lib/screens/auth/login_screen.dart` - login UX and magic-link behavior.
- `lib/screens/auth/signup_screen.dart` - sign-up and invite-code entry.
- `lib/screens/auth/set_password_screen.dart` - new. Mandatory, non-dismissible
  screen (`PopScope(canPop: false)`, `automaticallyImplyLeading: false`, no
  skip button) shown by `AppNavigator` to any account with
  `!AuthProvider.hasPasswordSet`. Password + confirm-password form, calls
  `AuthProvider.setPassword`.
- `lib/screens/profile/profile_form_screen.dart` - profile create/edit form.
  Tags a brand-new profile's `deep_details['has_password']` at creation time
  when `AuthProvider.authenticatedWithPassword` is true (i.e. just came from
  `signUpWithEmail`/`signInWithEmail`), and explicitly preserves
  `has_password` across an edit of an existing profile — the save path
  otherwise rebuilds `deep_details` from scratch on every save, which would
  silently wipe this flag. See `06_supabase_and_data_model.md`.
- `lib/providers/auth_provider.dart` - auth state and sign-in helpers. Has
  `AuthProvider.forTesting(...)` (`@visibleForTesting`) so widget tests can
  construct auth state without a live Supabase connection; not used by
  production code. `signUpWithEmail` now always calls
  `_loadCurrentMemberProfile()` before deciding a signup is fresh (defense in
  depth alongside the `SupabaseService` identities check — see below), fixing
  the duplicate-profile-row incident. New: `hasPasswordSet` getter
  (`deep_details['has_password']`), `setPassword(password)`,
  `authenticatedWithPassword` (transient per-session flag). `signInWithEmail`
  self-heals `has_password` on first successful password login if missing.
  See `02_work_completed.md` and `04_current_risks.md`.
- `lib/providers/settings_provider.dart` - locale/offline-state provider. Has
  `SettingsProvider.forTesting()`/`debugNotifyForTesting()`
  (`@visibleForTesting`), same testing-only purpose as `AuthProvider.forTesting`.
- `lib/services/supabase_service.dart` - Supabase auth calls. `signUpWithEmail`
  now checks `response.user!.identities?.isEmpty` after `signUp()` and throws
  `AuthException('vanshavali_email_already_registered')` if the email was
  already registered (Supabase's anti-enumeration behavior otherwise returns
  a false-success) — see `02_work_completed.md` and
  `06_supabase_and_data_model.md`. New: `updatePassword(String newPassword)`.

## Family tree and relations
- `lib/screens/family/family_tree_screen.dart` - tree visualization, built on
  the `graphview` package (`BuchheimWalkerAlgorithm`) instead of hand-rolled
  pixel-math positioning. Each person + their spouse(s) is modeled as one
  "couple-unit" node (graphview's algorithm is single-parent-per-node, so
  couple-units are the workaround for two-parents-converge-on-child and
  multi-spouse). Has explicit zoom in/out/reset controls plus
  InteractiveViewer pan/zoom; tapping a node to re-center triggers a real
  `loadEgoNetwork` fetch. Hardened against four issues found across two
  rounds of live-device/code-review bug-hunting (full case study in
  `02_work_completed.md`; risk framing in `04_current_risks.md`): bypasses
  `GraphView.builder` entirely for the single-node (brand-new profile) case;
  caches built `Graph`/`Node` objects in `_buildTreeDataCached` keyed on
  ego-network/spouse-link reference-equality plus focus id and
  sibling-visibility, instead of rebuilding them on every widget rebuild;
  controller ownership for the default (graphview) view lives in a dedicated
  `_GraphViewHost` `StatefulWidget` (its own `initState`/`dispose` create and
  release the `GraphViewController`/`TransformationController` fresh on every
  mount) rather than in `_FamilyTreeScreenState` — `_FamilyTreeScreenState`
  only holds a nullable `GraphViewController? _graphController`, set/cleared
  via a split `onControllerCreated`/`onControllerDisposed` callback pair (the
  disposal side checks `identical()` before clearing, to survive a
  same-`setState` remount-then-unmount race — see `04_current_risks.md`
  "Finding #4"). The pedigree view's `InteractiveViewer` uses a completely
  separate, State-owned `_pedigreeTransformController`, never shared with
  `_GraphViewHost`'s controller. **This controller-lifecycle area has had two
  fixes independently found incomplete on review — treat any future change
  here as high-risk, see `04_current_risks.md`.** Also exposes `buildTreeData`
  and `buildPedigreeChain` as pure top-level functions for unit testing —
  `buildPedigreeChain` has a visited-ids cycle guard against bad
  `father_id`/`mother_id` data (rendering-side only, see
  `06_supabase_and_data_model.md` for the data-entry-layer gap).
- `lib/screens/family/member_detail_screen.dart` - member details and relation
  actions; spouses now display as a list with a remove affordance.
- `lib/screens/family/add_family_member_screen.dart` - relation creation,
  duplicate guards, spouse-child linking prompt. Adding a spouse is always
  available (not hidden after the first); duplicate check is per-pair, not
  "already has a spouse". Cardinality/duplicate/cycle rules are extracted as
  pure, top-level functions (`blockedOneToOneRelation`,
  `isSpouseAlreadyLinked`, `childrenNeedingOtherParent`,
  `wouldCreateAncestryCycle`) so they're unit-testable without a live
  Supabase connection or widget tree — see
  `test/screens/family/relation_guards_test.dart` below.
  `wouldCreateAncestryCycle` (new) blocks linking an existing member as
  father/mother when doing so would make the target their own descendant's
  descendant (an ancestry cycle) — the app-level closure of the
  previously-open data-entry-layer gap, see `04_current_risks.md` and
  `06_supabase_and_data_model.md`.
- `lib/providers/family_provider.dart` - network loading, relation helpers,
  linking methods. `loadEgoNetwork` now calls
  `SupabaseService.getEgoCentricNetwork` (the `get_ego_network` RPC), not a
  whole-table fetch. Also has `removeSpouse`.
- `lib/screens/home/home_screen.dart` - bottom-nav tabs (dashboard / family
  tree / search / settings). `_SearchTab` takes an `onMemberSelected`
  callback that calls `FamilyProvider.loadEgoNetwork(member.id)` and switches
  to the Family Tree tab (index 1) — previously tapping a search result did
  nothing visible (called `setCenterMember` only, behind an unimplemented
  "Navigate to tree view" comment).
- `lib/models/family_member.dart` - persisted family member schema. `spouseId`
  field removed (Hive field index 5 retired, never reused); new `SpouseLink`
  class represents a `spouse_relationships` row. Has an `initial` getter
  (avatar-initial helper, falls back to `'?'` for an empty name) used at all
  8 avatar-initial call sites instead of `firstNameEn.substring(0, 1)`.
- `lib/services/local_storage_service.dart` - local cache and offline queue.
  Ego-network caching reworked to be incremental (upserts visited
  neighborhoods) instead of wipe-and-replace. Still has whole-table
  `getAllFamilyMembers`/`syncData`, used only by the explicit, user-initiated
  "Sync Data" settings action (offline-prep for low-connectivity use, not part
  of the routine tree-view path).
- `lib/services/supabase_service.dart` - `getEgoCentricNetwork` actually calls
  the `get_ego_network` RPC now; `removeSpouseLink` added; `getAllFamilyMembers`
  retained for the explicit full-sync path only.

## Localization
- `lib/l10n/app_en.arb`
- `lib/l10n/app_gu.arb`
- `lib/l10n/app_localizations.dart`
- `l10n.yaml`
- New keys this round (both locales): `errorEmailAlreadyRegistered`,
  `setPasswordTitle`, `setPasswordDescription`, `setPasswordButton`,
  `passwordSetSuccess`. `errorEmailAlreadyRegistered`'s wording is slightly
  inaccurate (mentions a Settings entry that doesn't exist) — see
  `04_current_risks.md`.

## Configuration and backend
- `lib/config/app_config.dart` - Supabase config, deep-link config, app metadata.
- `supabase/migrations/001_initial_schema.sql` - base schema.
- `supabase/migrations/002_invite_code.sql` - invite-code migration.
- `supabase/migrations/003_multiple_spouses.sql` - `spouse_relationships` table,
  drops `spouse_id`, updates `get_ego_network`. Applied to live Supabase — see
  `06_supabase_and_data_model.md`.
- `supabase/migrations/004_fix_spouse_rls.sql` - tightens the
  `spouse_relationships` INSERT/DELETE RLS policies from 003 (closes a gap
  where either side of the pair alone could satisfy the check). Not yet
  applied to live Supabase — see `06_supabase_and_data_model.md` and
  `04_current_risks.md`.

## Tests
- `test/screens/family/family_tree_data_test.dart` - unit tests for the
  top-level `buildTreeData` function in `family_tree_screen.dart`.
- `test/screens/family/family_tree_pedigree_test.dart` - unit tests for
  `buildPedigreeChain`, including the cycle-guard regression cases.
- `test/screens/family/family_tree_screen_rebuild_test.dart` - 6 widget tests
  (grew from 1) covering every way `_GraphViewHost`'s Element has been found
  to unmount/remount: an incidental rebuild from an unrelated provider,
  unmounting entirely, the `isLoading` spinner swap (the actual on-device
  trigger for crash C), Family↔Pedigree view-mode switching, and toggling the
  siblings badge (the trigger for finding #4's same-`setState` callback
  race). The last two tests assert the zoom-in button actually changes the
  `InteractiveViewer`'s transform scale, not just that no exception was
  thrown — a weaker "no exception" check would not have caught finding #4.
  See `02_work_completed.md` and `04_current_risks.md`.
- `test/screens/family/relation_guards_test.dart` - duplicate father/mother/
  spouse relation guard tests, plus `wouldCreateAncestryCycle` cycle-guard
  tests (self-reference, direct/multi-generation/maternal-branch-only
  cycles, a legitimate non-cycle sibling case, dead-end termination, the
  `maxVisited` bound against pre-existing bad data, null-resolver handling).

## UI helpers
- `lib/widgets/common_widgets.dart` - shared widgets; now also has
  `friendlyErrorMessage()` (replaces raw `e.toString()` in user-facing
  snackbars) and the `SectionCard` widget (shared Card/Padding/Column
  boilerplate used in settings/profile-form/member-detail).
  `friendlyErrorMessage()` maps the `vanshavali_email_already_registered`
  marker to the l10n key `errorEmailAlreadyRegistered` — see
  `02_work_completed.md`.
- `lib/widgets/gujarati_edit_sheet.dart`
- `lib/theme/app_theme.dart`
- `lib/theme/app_spacing.dart` - new `AppSpacing` token set, wired into the
  theme including button/icon-button minimum tap-target sizes.
