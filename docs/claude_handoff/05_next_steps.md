# Next Steps for Claude Code

## Blocking — open items from the auth incident this round
0a. **Confirm the duplicate-`family_members`-row cleanup for
    priyanshumakwana920@gmail.com is actually complete.** A read-only
    diagnostic SQL query was given to the project owner (in a scratchpad
    file, not committed) to inspect the duplicate rows before deciding what
    to delete/merge — this has not been confirmed done. Do not assume this
    account (or any account that hit the same bug) works correctly until
    verified. See `04_current_risks.md`.
0b. Manually re-verify the fixed signup-on-existing-email path live: attempt
    email+password signup with an email that already has an account (e.g. via
    magic link) and confirm it now shows `errorEmailAlreadyRegistered`
    instead of creating a duplicate profile. Not yet re-tested live post-fix
    — only `flutter analyze`/`flutter test` back the fix currently.
0c. Manually verify the mandatory `SetPasswordScreen` flow end-to-end on
    device (set a password, confirm it persists via `hasPasswordSet` /
    `deep_details['has_password']`, confirm the self-heal path in
    `signInWithEmail` for accounts that already had a password before this
    tracking existed). No automated coverage exists for this yet either — see
    `02_work_completed.md`.

## Blocking — do this before trusting spouse-relationship RLS in production
0. **Apply `supabase/migrations/004_fix_spouse_rls.sql` to the live Supabase
   project** via the SQL editor (same process as 001-003). Until this runs,
   the live `spouse_relationships` INSERT/DELETE policies are still the
   looser 003 versions — see `04_current_risks.md` and
   `06_supabase_and_data_model.md`.

## Done since the last handoff (previously listed here as blocking/pending)
- ~~Apply migration 003~~ — applied; confirmed indirectly via live-device
  testing of the tree screen (couple-unit rendering depends on
  `spouse_relationships`/`get_ego_network`, and it ran with no schema/RPC
  errors).
- ~~Verify the new graphview-based tree layout visually~~ — done via live
  Android device testing; found and fixed three real crashes (single-node
  new-profile, app-resume rebuild, leave-screen double-dispose). See
  `02_work_completed.md` and `08_verification_log.md`.
- ~~Run `flutter analyze` and a device build before making broader changes~~
  — `flutter analyze` clean, 67/67 tests pass, `flutter build apk --debug`
  and `flutter build web` both succeed.

## Immediate next work
1. Apply migration 004 (see blocking item above), then verify the
   `spouse_relationships` INSERT/DELETE policies actually reject the
   no-connection case they were written to close.
2. Verify the multi-spouse add/remove flow end-to-end on device: adding a
   second spouse is always available, duplicate-pair guard works,
   spouse-child linking prompt still only offers children with an empty
   other-parent slot, `removeSpouse` works with confirmation. Not covered by
   this round's device testing, which focused on the tree-screen crashes.
3. Verify the login screen stays put after magic-link send and only shows the snackbar.
4. Verify father and mother still cannot be added twice.
5. Verify invite-code claim flow still works after the auth changes.
6. Confirm `loadEgoNetwork` is genuinely fetching only the ego-centric network
   at runtime (not the whole table) — this was fixed at the code level but
   still needs a live check, e.g. via Supabase logs.
7. ~~Decide on the data-entry-layer ancestry-cycle gap~~ — an app-level guard
   (`wouldCreateAncestryCycle` in `add_family_member_screen.dart`) now blocks
   "Add Father"/"Add Mother" → "Link Existing" from creating a cycle. Still
   open: whether a database-level check (e.g. an RLS/trigger check on
   `family_members` writes) is also wanted, since the current guard only
   covers the one app entry point and would not stop a cycle created via
   direct API/SQL access. See `04_current_risks.md`.
8. Resolve the open product question on Pedigree View's ~1-generation cap
   (see `02_work_completed.md`) — decide whether the ego-centric-only fetch
   is intentional, or whether a dedicated ancestor-chain RPC is wanted for
   deeper pedigree views.

## Medium priority improvements
- Add focused widget tests for the login magic-link UX, multi-spouse
  add/remove, and the new auth-incident/set-password code (`signUpWithEmail`
  identities check, `hasPasswordSet`, `setPassword`, `SetPasswordScreen`) —
  relation-gating and tree-rebuild coverage now exist (see
  `relation_guards_test.dart`, `family_tree_data_test.dart`,
  `family_tree_pedigree_test.dart`, `family_tree_screen_rebuild_test.dart`),
  but these areas still have no automated coverage.
- Add a better project-specific README that explains setup and architecture
  (still a generic Flutter starter README as of this writing).
- Consider improving the unreachable deep-link story with clearer fallback UX.
- Fix `errorEmailAlreadyRegistered`'s copy (both locales) — it currently says
  the user can set a password "from Settings after logging in", but there is
  no such Settings entry; the actual mechanism is the mandatory
  `SetPasswordScreen`. See `04_current_risks.md`.
- Commit the current working tree to git — the repo was `git init`'d but has
  zero commits; all work described in this handoff (including this round's
  bug fixes and the auth incident fix/set-password feature) is uncommitted.

## Explicitly declined by project-owner decision — not a gap, do not re-raise
- Phone number login/auth. Reason: ongoing real SMS-provider costs conflict
  with the project's zero-cost requirement. This matches CLAUDE.md §2, which
  already lists phone auth as an if-budget-allows-later item, not a v1
  requirement. See `02_work_completed.md`.

## Longer-term work still left to achieve
- Complete the full dashboard/profile editing experience if anything is still incomplete.
- Harden offline sync behavior for relation edits and invite claims.
- Improve the tree visualization for larger families if overlap appears, now that it's graphview-based rather than hand-rolled.
- Add release-ready app-link handling if real-domain deep links become necessary later.
- Review the UI for the lowest-tech users and simplify any confusing flows.
