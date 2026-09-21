# Vanshavali Autonomous Improvement Sprint — Progress Tracker

**This file is the loop's memory.** Each 10-minute iteration: read this, advance the
next highest-value unchecked task, update status here. Started 2026-09-22.

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
| 1 | Rate limiting | TODO | Supabase auth rate limits (config.toml [auth.rate_limit] exists) + client-side debounce/in-flight guards. Split: dashboard=OWNER, client=code. |
| 2 | API limits | TODO | Supabase free-tier caps + `max_rows` (config has 1000). Verify + document. Mostly OWNER. |
| 3 | Spending caps | OWNER | Supabase free plan = no billing; ensure "spend cap" stays ON so it can never auto-upgrade to paid. Dashboard verify. NOT payments. |
| 4 | Error handling | TODO | Audit all await calls in providers/services; ensure try/catch + friendlyErrorMessage everywhere. Partly done in auth. |
| 5 | Loading states | TODO | Audit every screen with async data; ensure spinner/skeleton. |
| 6 | Empty states | TODO | Directory, tree, search — friendly empty UI + bilingual copy. |
| 7 | Handle failed requests | TODO | Cache-fallback pattern (AuthProvider already does this) applied to all fetches. |
| 8 | Handle API timeouts | TODO | Add `.timeout()` to network calls (SupabaseService); surface reachability message. |
| 9 | Prevent duplicate submissions | TODO | Disable submit while in-flight: add-member, profile save, claim, invite. |
| 10 | Prevent duplicate payments | N/A | **No payment system exists in this app.** Nothing to do. Recorded for completeness. |
| 11 | Optimise DB queries | RESEARCHING | Agent R-infra. EXPLAIN the RPCs (get_ego_network, ancestor_chain, search). |
| 12 | DB indexes | RESEARCHING | Agent R-infra. father_id/mother_id/auth_user_id/village_origin + pg_trgm for search. |
| 13 | Paginate large results | TODO | Directory "All" tab (whole DB) MUST paginate. RPC + infinite scroll. |
| 14 | Compress files | TODO | Tie to profile-pic (F-A): compress image client-side before upload. |
| 15 | Limit upload sizes | TODO | Tie to profile-pic: client cap + Supabase Storage bucket policy. |
| 16 | Cache repeat requests | TODO | Hive cache exists; extend to search/directory + add TTL where useful. |
| 17 | Uptime monitoring | RESEARCHING | Agent R-infra. Free options (UptimeRobot/cron-job.org) + free-tier keep-alive ping. Signup=OWNER. |
| 18 | Error logging + Slack forward | RESEARCHING | error_logs table ALREADY EXISTS (migration 008). Research: can an individual contributor forward to Slack (incoming webhook feasibility). Agent R-infra. |
| 19 | Simultaneous-user test | TODO | Write a load-test script (k6/dart) hitting read RPCs; run vs local Supabase. |
| 20 | Backup / restore test | RESEARCHING | Free tier has no PITR. pg_dump/restore script + doc. Agent R-infra. Creds=OWNER. |

## B. App-specific features

| # | Task | Status | Notes |
|---|------|--------|-------|
| F-A | Node profile-pic upload | RESEARCHING | Agent R-media: Supabase Storage free tier (1GB), image_picker + compression, size cap, render on node + profile. |
| F-B | Village field mandatory | IN-PROGRESS | Agent → sprint/quick-ui-wins. Validation in profile_form + add_family_member + l10n. |
| F-C | Make everything searchable | TODO | Search names(en/gu)/village/city, not just village. Local + RPC (search_family_members). |
| F-D | Any-level village selectable | TODO | village_picker: allow district/taluka/village as origin; don't force deepest leaf. |
| F-E | Directory All / My-family tabs | TODO | Replace flat list. "All"=entire DB (paginated, needs #13). "My family"=connected component to me. |
| F-F | "View tree" from each profile | TODO | member_detail → family_tree_screen centered on that member. |
| F-G | Tapping relatives opens profile | IN-PROGRESS | Agent → sprint/quick-ui-wins. BUG: tiles route to add-new; must open that member's profile. |
| F-H | Village subtext under node names | IN-PROGRESS | Agent → sprint/quick-ui-wins. Small village_origin line under name; watch overflow tests. |
| F-I | Duplicate-detection → claim recommendation | RESEARCHING | Agent R-claim. On create, detect existing match (self+parents+params) → send claim request to existing node's tree. merge_requests (migration 009) may be reusable. Heavy research first. |

---

## Research agents dispatched (iteration 1, 2026-09-22)
- **R-infra** → tasks 11,12,17,18,20 (+2,3,19 context): Supabase free-tier hardening + Slack + uptime + backup + query/index audit.
- **R-media** → F-A + 14,15: profile-pic upload architecture on free tier.
- **R-claim** → F-I: duplicate-detection + claim/merge recommendation system design.

## Iteration log
- **2026-09-22 i1:** Set up loop (cron 1e6d184c), created tracker + owner-action doc, triaged all 30 items (marked payments N/A), dispatched 3 research agents (R-infra, R-media, R-claim). Next: collect research → begin implementation on the quickest wins (F-B, F-G, F-H) while research lands.
