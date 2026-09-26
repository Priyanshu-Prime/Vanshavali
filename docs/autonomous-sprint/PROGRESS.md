# Vanshavali Autonomous Improvement Sprint — Progress Tracker

**This file is the loop's memory.** Each 10-minute iteration: read this, advance the
next highest-value unchecked task, update status here. Started 2026-09-22.

> Current-state handoff for a fresh session: `docs/claude_handoff/` (start at its README).
> This file is the detailed per-task ledger behind that handoff. Shipped as
> `0.1.0-alpha.2+17`; open owner items in `NEEDS-OWNER-ACTION.md`.

## Ground rules (do not violate)
- **Release only from main; never from a feature branch.** Merge to main only when a
  feature is complete AND tested, then release. (See memory: release-only-from-main.)
- Every task lands on its own `sprint/<slug>` branch. Code-writing subagents use
  **worktree isolation**. Research subagents are read-only (no worktree).
- Use **graphify** (`graphify query/explain/path`) to orient before grepping.
- Use **ponytail** discipline: smallest diff that works, reuse existing patterns.
- **Zero-cost constraint holds.** Nothing that incurs a bill. Supabase free tier only.
- Blocked / owner-action → log in `NEEDS-OWNER-ACTION.md` and move on. Never idle-wait.
- Bilingual EN/GU mandatory for every user-facing string (l10n-strings skill).

## Status legend
`TODO` · `RESEARCHING` (agent out) · `RESEARCHED` (design ready) · `IN-PROGRESS`
(branch open) · `PR` (branch done, awaiting bundle+release) · `DONE` (merged to main)
· `N/A` (does not apply) · `OWNER` (needs owner action — see NEEDS-OWNER-ACTION.md)

---

## A. Infra / hardening requirements

| # | Task | Status | Notes |
|---|------|--------|-------|
| 1 | Rate limiting | PR | searchMembers debounce (350ms + stale-drop) DONE on sprint/db-foundation (c152c39). Prod auth limits=OWNER. |
| 2 | API limits | TODO | Supabase free-tier caps + `max_rows` (config has 1000). Verify + document. Mostly OWNER. |
| 3 | Spending caps | OWNER | Supabase free plan = no billing; ensure "spend cap" stays ON so it can never auto-upgrade to paid. Dashboard verify. NOT payments. |
| 4 | Error handling | MERGED | Providers wrap awaits in try/catch + friendlyErrorMessage; added data.* error logging (hardening). |
| 5 | Loading states | MERGED | Audited all primary screens (tree/home/requests/detail already had them); directory via F-E. |
| 6 | Empty states | MERGED | AppWidgets.empty on directory/tree/requests; audited others. |
| 7 | Handle failed requests | MERGED | Cache-fallback on all provider reads (mirrors AuthProvider); timeout degrades to cache. |
| 8 | Handle API timeouts | MERGED | Central 15s `_t()` seam in SupabaseService on hot reads/mutations + claim RPCs → errorTimeout msg + cache fallback. |
| 9 | Prevent duplicate submissions | MERGED | `_submitting` re-entry latch on add-member; set-password guard; profile/claim/invite already guarded. |
| 10 | Prevent duplicate payments | N/A | **No payment system exists in this app.** Nothing to do. Recorded for completeness. |
| 11 | Optimise DB queries | PR | mig 015 (6248b20) adds pg_trgm; owner must apply. FKs already covered. |
| 12 | DB indexes | PR | mig 015 DONE on sprint/db-foundation (6248b20): pg_trgm + 6 GIN + dropped dead index. OWNER applies SQL. |
| 13 | Paginate large results | MERGED | DONE via F-E getMembersPage (range pagination, page 50, infinite scroll). No migration needed. |
| 14 | Compress files | PR | DONE via F-A: image_picker native resize 512px/q70 → ~30-80KB. In integration. |
| 15 | Limit upload sizes | PR | DONE via F-A: 300KB client cap + server file_size_limit on bucket (mig 016). In integration. |
| 16 | Cache repeat requests | DONE | Satisfied by existing Hive cache (members/profiles/tree) + hardening's timeout→cache fallback everywhere. Optional TTL deferred (not needed at 500-user scale). |
| 17 | Uptime monitoring | PR | ping() RPC DONE in mig 015 (sprint/db-foundation). OWNER: apply 015 + point UptimeRobot at rpc/ping (URGENT vs 7-day auto-pause). |
| 18 | Error logging + Slack forward | RESEARCHED | error_logs EXISTS (008). Non-admin usually can't make Slack webhook → OWNER (personal workspace/Discord). Build pg_net trigger AFTER owner has webhook. |
| 19 | Simultaneous-user test | PR | scripts/load-test/load.js (k6, ramps to 50 VUs on ego/connected-tree RPCs). On integration. OWNER runs with REF/ANON/ROOT. |
| 20 | Backup / restore test | PR | scripts/backup/{backup.sh,README.md} (pg_dump session-pooler + restore drill). On integration. Creds+run=OWNER. |

## B. App-specific features

| # | Task | Status | Notes |
|---|------|--------|-------|
| F-A | Node profile-pic upload | MERGED | DONE + merged into sprint/integration (green). mig 016 (OWNER applies), model avatarUrl, image_picker+cached_network_image, upload flow+states, tree/detail render, iOS Info.plist perms. Needs on-device e2e. |
| F-B | Village field mandatory | PR | DONE on sprint/quick-ui-wins (c08630c). Shared village_picker_field validator; both forms. Needs on-device eyeball. |
| F-C | Make everything searchable | MERGED | searchPlaces() matches district/taluka/village; picker hint updated. MERGED into integration (146 tests). |
| F-D | Any-level village selectable | MERGED | "Use this place" at district/taluka rows; any level stored as village_origin name. MERGED into integration. |
| F-E | Directory All / My-family tabs | MERGED | Tabs + getMembersPage range-pagination (no migration; RLS 006) + offline fallback + loading/empty. MERGED (149 tests). |
| F-F | "View tree" from each profile | MERGED | "View family tree" button → FamilyTreeScreen(focusMember) → loadEgoNetwork (reuses ego-center). MERGED (149 tests). |
| F-G | Tapping relatives opens profile | VERIFY | ALREADY CORRECT in code (member_detail_screen: existing relatives tap→profile; add only when absent). User's bug likely an OLD build. Confirm on-device on new build. |
| F-H | Village subtext under node names | PR | DONE on sprint/quick-ui-wins (182d3a2). Muted subtext in _PersonBox, guarded, overflow test passes. |
| F-I | Duplicate-detection → claim recommendation | MERGED | DONE, MERGED into integration (151 tests). mig 017 (find_duplicate_candidates + merge_requests ext + claim RPCs), dup-match sheet, requests inbox+badge, both fire points. OWNER: apply mig 017 + approver-eligibility decision (see NEEDS-OWNER-ACTION). LESSON: never give agents `git -B`/force/reset — hangs a background agent on a permission prompt; use plain `-b`+new name. |

---

## Research agents dispatched (iteration 1, 2026-09-22)
- **R-infra** → tasks 11,12,17,18,20 (+2,3,19 context): Supabase free-tier hardening + Slack + uptime + backup + query/index audit.
- **R-media** → F-A + 14,15: profile-pic upload architecture on free tier.
- **R-claim** → F-I: duplicate-detection + claim/merge recommendation system design.

## Migration numbering plan (locked, avoids collisions)
- **015** = pg_trgm + 6 GIN indexes + DROP idx_family_members_names + `ping()` RPC (db-foundation)
- **016** = `avatar_url` + `avatars` bucket + 4 storage policies (profile-pic; reuses can_edit_family_member)
- **017** = `find_duplicate_candidates` + merge_requests extension + claim RPCs (claim system; reuses 015 indexes)
All migrations are applied by OWNER in the Supabase SQL editor — the loop writes the files, owner runs them.

## Feature branches (integrate near the end onto a release branch, then main → release)
- **`sprint/integration`** ← HOME/base. = main + quick-ui-wins + db-foundation + tracker docs. analyze+145 tests green. All NEW feature branches fork from here; completed branches merge back in.
- `sprint/coordination` — original tracker branch (superseded by integration).
- `sprint/quick-ui-wins` (in worktree agent-a624a8e17be93efff): F-B, F-H committed. F-A must build on top (shared _PersonBox).
- `sprint/db-foundation` (off main) — DONE: mig 015 (6248b20) + searchMembers debounce (c152c39). Ready to integrate.
- `sprint/profile-pic` (off quick-ui-wins) — F-A DONE, MERGED into integration. mig 016.
- `sprint/village-picker-levels` (off integration) — F-C/F-D DONE, MERGED into integration.
- `sprint/directory-tabs` (off integration) — F-E DONE, MERGED into integration.
- `sprint/view-tree` (off integration) — F-F DONE, MERGED into integration.

## Integration state (2026-09-22 i10): CODE-COMPLETE, all green, 151 tests
Merged into sprint/integration: quick-ui-wins (F-B,F-H), db-foundation (mig015), profile-pic (F-A,
mig016), village-picker-levels (F-C,F-D), directory-tabs (F-E), view-tree (F-F), claim-system-v2
(F-I, mig017), hardening (#4,#5,#6,#7,#8,#9) + ops scripts (#19,#20).
✅ ALL 9 APP FEATURES DONE. ✅ DONE infra: #1,#4,#5,#6,#7,#8,#9,#11,#12,#13,#14,#15,#17,#19,#20.
#16 cache = SATISFIED by existing Hive cache + the hardening's cache-fallback-on-timeout everywhere
(optional TTL enhancement deferred, not needed at this scale). #18 Slack = OWNER-BLOCKED (needs webhook).
#2,#3 = OWNER (dashboard). Nothing left to implement.

## 🚦 RELEASE READINESS — gated on OWNER applying migrations FIRST (do NOT auto-release before)
The code is done + tested, but **migrations 015/016/017 must be applied to the DB BEFORE the release
is installed**, or the app breaks:
- mig 016 adds `family_members.avatar_url`. The app now WRITES avatar_url on every profile
  save/create → if the column doesn't exist, profile save FAILS (unknown column). HARD dependency.
- mig 017 adds find_duplicate_candidates + claim RPCs (dup-check on create, claim flow).
- mig 015 adds search indexes + ping() (perf + keep-alive).
So the release sequence is: OWNER applies 015→016→017 in SQL editor → THEN merge integration→main
(bump version) → CI builds+distributes → owner tests. Releasing before the migrations would ship a
broken profile-save to testers (violates the "don't ship broken / verify before shipping" rule).

## Iteration log
- **2026-09-22 i1:** Set up loop (cron 1e6d184c), created tracker + owner-action doc, triaged all 30 items (marked payments N/A), dispatched 3 research agents (R-infra, R-media, R-claim). Next: collect research → begin implementation on the quickest wins (F-B, F-G, F-H) while research lands.
- **2026-09-22 i1b:** ALL 3 research reports in → research/{infra,profile-pic,claim-system}.md. Locked migration numbering (015/016/017). quick-ui-wins done: F-B + F-H committed, F-G already correct. Owner-action items appended. Next: spawn sprint/db-foundation (015 + searchMembers debounce), then F-A on top of quick-ui-wins, then F-C/D/E/F search+directory+tree-nav, then F-I claim.
