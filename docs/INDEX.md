# Vanshavali — Documentation Index

**The map of every doc in this project.** Start at the top; each entry says what it's for
and links to it. Tags: **[repo]** = committed to git (portable, in the public repo) ·
**[local]** = on-disk only, gitignored (kept out of the public repo — internal Claude/agent
notes; present in the working tree on this machine) · **[branch:x]** = lives on branch `x`,
not yet on `main`.

Released state at last update: **v0.1.0-alpha.2+17** (main) — see the handoff for current status.

---

## 🚀 Start here (current state · last thing done · what to improve next)
- **[local] [`claude_handoff/README.md`](claude_handoff/README.md)** — the canonical
  session-to-session brief. Read this first: current state, last thing shipped, next steps.
- **[repo] [`autonomous-sprint/PROGRESS.md`](autonomous-sprint/PROGRESS.md)** — the detailed
  ledger of the latest improvement sprint (every requirement + status, newest work).
- **[repo] [`autonomous-sprint/NEEDS-OWNER-ACTION.md`](autonomous-sprint/NEEDS-OWNER-ACTION.md)** —
  everything currently waiting on the owner (migrations status, UptimeRobot, Slack, decisions).

## 📋 Handoff brief — `claude_handoff/` [local, on-disk] 
The durable, structured handoff. Refreshed to the +17 release.
- [`claude_handoff/00_repo_map.md`](claude_handoff/00_repo_map.md) — module/folder map of the codebase.
- [`claude_handoff/01_requirements_and_goals.md`](claude_handoff/01_requirements_and_goals.md) — product requirements & constraints (zero-cost, bilingual, low-tech).
- [`claude_handoff/02_work_completed.md`](claude_handoff/02_work_completed.md) — everything shipped, incl. the +17 sprint.
- [`claude_handoff/03_recent_requests_and_commands.md`](claude_handoff/03_recent_requests_and_commands.md) — recent owner requests & key commands.
- [`claude_handoff/04_current_risks.md`](claude_handoff/04_current_risks.md) — open risks.
- [`claude_handoff/05_next_steps.md`](claude_handoff/05_next_steps.md) — **what to improve next.**
- [`claude_handoff/06_supabase_and_data_model.md`](claude_handoff/06_supabase_and_data_model.md) — full schema / RPCs / RLS through migration 017.
- [`claude_handoff/07_file_touchpoints.md`](claude_handoff/07_file_touchpoints.md) — which files to touch per area.
- [`claude_handoff/08_verification_log.md`](claude_handoff/08_verification_log.md) — test/verify status (analyze + 151 tests green; on-device pending).
- [`claude_handoff/09_session_timeline.md`](claude_handoff/09_session_timeline.md) — chronology.

## 🧩 Features (as built / intended)
Each feature's design + status. Detail lives in the sprint research docs and the schema doc.
- **Profile pictures** — optional node avatar (Supabase Storage, client compress + size cap).
  Design: **[repo]** [`autonomous-sprint/research/profile-pic.md`](autonomous-sprint/research/profile-pic.md) · schema: `claude_handoff/06` (mig 016 `avatar_url` + `avatars` bucket).
- **Duplicate-detection → claim request** — on create, find likely-existing person and offer a
  claim instead of a duplicate. Design: **[repo]** [`autonomous-sprint/research/claim-system.md`](autonomous-sprint/research/claim-system.md) · schema: mig 017 (`find_duplicate_candidates`, `merge_requests` ext, claim RPCs).
- **Village picker — search + select at any level** (district/taluka/village). See PROGRESS.md (F-C/F-D).
- **Directory — All / My-family tabs** (paginated "All" via `getMembersPage`). See PROGRESS.md (F-E).
- **View family tree from a profile** — recenters the tree on that member. See PROGRESS.md (F-F).
- **Invite & WhatsApp onboarding** — deep-link claim flow + landing page.
  **[repo]** [`whatsapp_invite_flow.md`](whatsapp_invite_flow.md) · **[repo]** [`../landing/README.md`](../landing/README.md).
- **Phone OTP (SMS) sign-in** — BUILT but NOT LIVE / not on main. Lives on branch `fix/phone-otp`
  (Fast2SMS + DLT + Supabase Send-SMS hook). Doc: **[branch:fix/phone-otp]** `supabase/functions/send-sms-hook/README.md`.

## 🗄️ Architecture & data
- **[local]** [`claude_handoff/00_repo_map.md`](claude_handoff/00_repo_map.md) — code structure.
- **[local]** [`claude_handoff/06_supabase_and_data_model.md`](claude_handoff/06_supabase_and_data_model.md) — the schema/RPC/RLS source of truth.
- **[repo]** [`autonomous-sprint/research/infra.md`](autonomous-sprint/research/infra.md) — DB indexes, pagination, rate limits, uptime, backups, Slack research.
- Migrations live in `../supabase/migrations/` (001–017); RPC/RLS notes in `06`.

## 🔒 Process rules (agents MUST follow)
Also mirrored in Claude memory (`release-only-from-main`, `verify-on-device-before-shipping`).
1. **Release only from `main`** — never from a feature branch. Merge a feature to main only when
   complete AND tested, then release (merge + version bump → CI builds signed APK → Firebase).
2. **Verify on-device before shipping** user-facing auth/tree/deep-link changes — don't defer to testers.
3. **Never give a subagent a destructive git flag** (`-B`/`--force`/`reset`) — it silently hangs on a
   permission gate. Use plain `-b` + a fresh branch name.
4. **`graphify-out/` is gitignored** (generated locally by the graphify hooks; don't commit it).
Full rationale: `claude_handoff/README.md` and Claude memory.

## 🧪 Testing & ops
- **[repo]** [`test_scenarios.md`](test_scenarios.md) — manual test scenarios / checklist.
- **[local]** [`claude_handoff/08_verification_log.md`](claude_handoff/08_verification_log.md) — what's been verified.
- **[repo]** [`../scripts/e2e/README.md`](../scripts/e2e/README.md) — on-device emulator + local-Supabase E2E rig.
- **[repo]** [`../scripts/backend_audit/README.md`](../scripts/backend_audit/README.md) — schema/RLS audit scripts.
- **[repo]** [`../scripts/backup/README.md`](../scripts/backup/README.md) — pg_dump backup + restore drill (#20).
- **[repo]** `../scripts/load-test/load.js` — k6 simultaneous-user load test (#19).

## ⚙️ Project config & tooling
- **[repo]** [`../README.md`](../README.md) — project README (setup / overview).
- **[local]** `../CLAUDE.md` — project instructions for Claude (constraints, schema, dev phases).
- **[repo]** [`../.githooks/README.md`](../.githooks/README.md) — git hooks.

---
*Maintenance: when you add/rename a doc, add it here. When code changes the schema, RPCs, or a
feature, update `claude_handoff/06` + the relevant feature row and re-point links. Keep this index
and `claude_handoff/README.md` cross-linked as the two entry points.*
