# Release v0.1.0-alpha.2+18 — Verification & Bug-Fix Tracker

**THE live checklist for the current push.** Any session: read this first, do the next
unchecked action, update this file, repeat. Goal: exercise the `+17` sprint features on the
simulator, fix every bug found, then release `+18` from `main`. Started 2026-09-28.

> Sits on top of `claude_handoff/` (durable state) and `autonomous-sprint/PROGRESS.md`
> (feature ledger). This file is the *active* work log; when `+18` ships, fold the outcome
> into `08_verification_log.md` and delete/close this.

## Why this exists
`+17` is code-complete (151 unit tests green, migrations 015–017 on prod) but its
user-facing paths were **never exercised on a device** — the standing rule is verify
on-device before shipping. This push closes that gap via the `scripts/e2e` rig (real app on
an Android emulator against real local Supabase) plus manual spot-checks the rig can't cover.

## Environment (confirmed 2026-09-28)
- Local Supabase: **UP** (REST 200 on 5532x ports — the Windows port gotcha; `run_e2e.sh`
  reads ports dynamically via `supabase status -o env`, so no hardcoding needed).
- Flutter 3.38.8 stable. Emulator image installed (`vanshavali_test`, android-34 x86_64).
- `npx supabase db reset` in `run_e2e.sh` WIPES any manually-seeded data (fine — tests seed
  their own via `supabase/seed.sql`).

## How to run
```bash
scripts/e2e/start_emulator.sh          # boot emulator (once per session; ~2-5 min)
scripts/e2e/run_e2e.sh                  # whole suite (resets DB first)
scripts/e2e/run_e2e.sh integration_test/flows/<one>_test.dart   # single flow
```

## Verification matrix
Legend: ⬜ not run · 🔄 running · ✅ pass · ❌ fail (→ bug row) · ⏭️ manual-only

### A. Automated e2e regression (existing 15 flows — must stay green)
| Flow | Status | Notes |
|------|--------|-------|
| smoke_test | ⬜ | app boots → Login/onboarding |
| signup_claim (2.1, 2.4) | ⬜ | signup+invite claim; single-use code |
| claim_from_form (2.2) | ⬜ | |
| invalid_code (2.3) | ⬜ | |
| create_profile (3.1) | ⬜ | |
| edit_profile_persist (3.2) | ⬜ | |
| signout_escape (3.3) | ⬜ | |
| relations_and_ego (4.1, 4.6) | ⬜ | |
| add_sibling_and_link_child (4.10) | ⬜ | |
| edit_authorization (4.7) | ⬜ | |
| claimed_node_edit_guard (4.8) | ⬜ | |
| distant_ancestor_and_edit (4.9) | ⬜ | |
| delete_node (4.11) | ⬜ | |
| language_toggle (5.1) | ⬜ | |
| invite_deeplink (7.1) | ⬜ | |

### B. `+17` sprint features — NOT yet e2e-covered (the actual gap)
| Feature | Status | How to verify |
|---------|--------|---------------|
| F-A profile-pic upload/render/300KB cap/NULL→symbol | ⬜ | manual on emulator (image_picker) — hard to automate; needs a check |
| F-I duplicate-detection → claim request/approve/reject + self-approve block | ⬜ | can automate as a flow; `find_duplicate_candidates` verified working via `_apply.mjs` earlier |
| #8 15s timeout → cache fallback (no hang on slow/failed net) | ⬜ | manual — kill backend mid-read, confirm cache serves |
| F-E directory All/My-family tabs + pagination + offline | ⬜ | |
| F-F "view family tree" from a profile | ⬜ | |
| F-H village subtext on nodes / F-B mandatory-village validation | ⬜ | |

## e2e run #1 (2026-09-28, full suite) — INCOMPLETE (OS killed it for low memory)
DB reset clean (all 17 migrations + seed). Final tally **+6 -5** before the OS reaped the
background process for memory pressure while building flow #12 (`relations_and_ego`). **4 flows
never ran:** relations_and_ego, signout_escape, signup_claim, smoke.
- ✅ PASS (6): add_sibling_and_link_child, delete_node, distant_ancestor_and_edit, invalid_code,
  invite_deeplink (claim "success"), language_toggle.
- ❌ FAIL (5, all EARLY in the run → ENV-1): claimed_node_edit_guard, claim_from_form,
  create_profile, edit_authorization, edit_profile_persist.

### ⚠️ BLOCKER: memory pressure
The rig (Android emulator ~2.5GB + Docker Supabase + a per-flow Gradle rebuild holding ~400MB)
exceeds this machine's free RAM, so a full 15-flow run gets OOM-reaped. The harness will not
auto-restart the reaped process. **Options to unblock:** (a) close other apps / free RAM then
re-run; (b) run flows in small batches (e.g. the 5 failed ones only) instead of the whole
suite; (c) run on a physical Android device instead of the emulator (frees ~2.5GB). Needs an
owner call — see the check-in at the end of the session.

## Bugs found (this push)

### ENV-1: Docker VM clock drift → spurious JWT 401 / 0-row writes  [ENVIRONMENT, not app code]
- **Symptom:** 4 of 5 failing flows threw `PostgrestException PGRST303 "JWT issued at future"`
  (401); the 5th threw `PGRST116 "0 rows"` on `updateFamilyMember` — a cascade of the same
  cause (a skew-rejected setup write left no row to update).
- **Root cause:** the Docker Desktop WSL2 VM clock drifts ahead of the host (measured +7s and
  self-correcting). A token issued while the VM clock was ahead has an `iat` that PostgREST
  later sees as "in the future" once the clock corrects backward. **Not an app bug** — the app
  handled the 401 correctly ("falling back to local cache"); the test just can't find the
  not-yet-cached new row. Proof it's environmental: the SAME auth+write operations PASS in the
  later flows (invite_deeplink claim succeeded; delete_node + distant_ancestor writes passed)
  once the VM clock settled.
- **Fix:** resync the Docker VM clock (`wsl --shutdown` → Docker restarts engine → `supabase
  start`), then re-run. Only escalate to a real code investigation if a flow STILL fails on a
  settled clock. Prevention for future runs: resync before starting the suite.
- **Status:** confirming via targeted re-run of the 5 failed flows on a settled clock.

<!-- Real app-bug template:
### BUG-N: <title>  [OPEN|FIXED]
- Symptom / how found:  · Root cause:  · Fix (file:line, commit):  · Regression test:
-->

## Release gate (do NOT release until ALL true)
- [x] ~~Full e2e suite green on emulator~~ — replaced by owner decision (2026-10-10) with a
      full manual on-device run on the owner's phone against prod (see RESUMED section). The
      emulator rig can't run on this 8GB host.
- [x] F-A, F-I, timeout→cache exercised — on-device, recorded below
- [x] Every bug found is FIXED + has a regression test, or documented why not (logout-prefs
      fix is Hive-backed: verified on-device, no unit test; tree-fill fix covered by goldens)
- [x] `flutter analyze` clean + `flutter test` green (186)
- [x] On `main`, version bumped to `0.1.0-alpha.2+18`, released per CI path
- All 6 fixes re-verified on-device on the rebuilt `+18` APK (2026-10-10 21:27–21:30).
  Prod test data (4 profiles, 4 auth users, 2 merge_requests, 10 activity_log, 1 avatar)
  deleted; family_members back to 95. Test photos removed from the phone.

### Local build note
`android/gradle.properties` sets `-Xmx8G -XX:MaxMetaspaceSize=4G` (sized for CI). On this
8GB laptop that gets the build OOM-reaped; for local builds temporarily use
`-Xmx2G -XX:MaxMetaspaceSize=768m` (don't commit).

## ⏸️ PAUSED (owner decision, 2026-09-28)
Owner chose to pause verification here after the OOM blocker. State is fully captured above.
**To resume:** free RAM (or use a physical device), then re-run in small batches — start with the
5 failed flows to confirm ENV-1 (`scripts/e2e/run_e2e.sh integration_test/flows/create_profile_test.dart`
etc.), then the 4 unrun flows (relations_and_ego, signout_escape, signup_claim, smoke), then the
+17-feature checks (F-A profile-pic, F-I claim, timeout→cache). No app-code changes are pending;
nothing found so far requires a fix. Release `+18` only after the release-gate checklist is all ✅.

## ▶️ RESUMED 2026-10-10 — on-device run on the owner's phone (no Docker/emulator)
Owner chose a physical phone over the Docker rig (8GB host can't fit emulator + Docker).
Rig: Motorola Edge 50 Fusion (Android 16) over USB, driven via adb (screencap/uiautomator/
input). Build: signed release `+18` from `fix/plus17-integration` installed **over** `+17`
(same upload key — no uninstall, owner's login survived). Backend: **prod**, migration 018
applied by owner 2026-10-10. Test data: `test+a1010/b1010/c1010/d1010@example.com`,
"*Alphademo*/*Strangerdemo*" surnames — cleaned up at the end.

### Results (✅ pass · 🐞 bug found → fixed · 📝 UX note, not changed)
| Area | Result |
|------|--------|
| Upgrade +17→+18 in place, session kept | ✅ |
| Home / Directory (My family A→Z, Everyone A→Z by surname) | ✅ (📝 tabs sort by different keys) |
| Tree full/nearby/pedigree, village subtext, re-center from profile ("View family tree") | ✅ |
| Language toggle EN↔GU | ✅ |
| Settings → Sync Data | ✅ (📝 "Last synced" only tracks manual sync) |
| Settings version label | 🐞 showed `1.0.0` → **FIXED** (+ pubspec drift test) |
| Sign up (password, prod auto-confirm) → Complete Profile | ✅ |
| Mandatory village validation | ✅ |
| Profile form: Save with off-screen error looked dead; red errors stayed after fixing | 🐞 → **FIXED** (snackbar + live re-validate) |
| Village picker search with keyboard open (no overflow; taluka/district disambiguation) | ✅ |
| Gujarati auto-transliteration of names | ✅ |
| Profile photo: gallery pick, 7.3MB → 81KB compressed, stored, renders on profile page | ✅ |
| Photo missing on tree until manual refresh after own-profile save | 🐞 → **FIXED** (`memberChangedElsewhere`) |
| Add father placeholder (prefilled surname/gender, clear confirm dialog) | ✅ |
| Duplicate detection → "Is this the same person?" → claim request → waiting screen | ✅ (no duplicate row created) |
| Approver badge + inbox with requester email → Approve | ✅ (📝 badge is an unlabeled icon) |
| Claim inbox copy ("<name> wants to be linked" read as if placeholder asked) | 🐞 → **FIXED** copy, both locales |
| Claimant logs in after approval → lands as claimed node, NOT forced to Set Password | ✅ (`has_password` self-heal confirmed in DB) |
| Claimed node viewed by another user: no edit/delete | ✅ |
| Offline cold start: "Offline Mode" banner, Home/tree from cache, Directory "showing saved members" | ✅ |
| Logout wiped language + onboarding flag (next launch = English onboarding) | 🐞 → **FIXED** (`clearAll` keeps device prefs) |
| Tree connector lines struck through node names (translucent fill) | 🐞 → **FIXED** (opaque blended fill; goldens regenerated) |

### Migration 018 — server checks via API on prod (13/13 ✅)
Re-parent blocked (`vanshavali_parent_already_set`) and father unchanged · name+gender alone
not a duplicate · +village is · sibling (different first name) is not · claimant can file
`request_claim` · unrelated member can't see or approve · ring-2 grandparent can't approve
while a ring-1 relative is registered · self-approve blocked · close relative sees requester
email · reject works · rejected placeholder stays unclaimed.

### 📝 UX notes for owner sign-off (not changed — design decisions)
Home card doesn't show the user's own photo; child rows on profile show initials not photos;
photo on tree node is icon-sized; empty "Additional Details" card renders as a bare heading;
requests badge is an unlabeled icon; add-member form doesn't prefill the user's village.

### Env note
`SUPABASE_SERVICE_ROLE_KEY` in `supabase/.env.local` is rejected by prod ("Invalid API key")
— probably rotated. `SUPABASE_DB_URL` still works; admin-side checks used it instead.

## Iteration log
- **2026-09-28 i1:** Oriented from handoff/PROGRESS. Confirmed env (Supabase up, Flutter,
  emulator image). Created this tracker. Booting emulator; e2e suite next.
- **2026-09-28 i2:** Ran full e2e suite (run #1). +6 -5, then OS-reaped for low memory at flow
  #12. All 5 failures = ENV-1 (Docker VM clock drift → JWT 401 / 0-row cascade), NOT app bugs —
  same ops pass in later flows on the settled clock. Static-verified `updateFamilyMember` is a
  plain own-row update (no RLS bug); `distant_ancestor` edit passed same run. **Blocked on
  memory** (see BLOCKER above) — the heavy rig can't finish a full run here and the harness
  won't auto-restart it. Paused the loop to check in with the owner on how to re-run (free RAM /
  batch flows / physical device). No app-code changes needed so far.
