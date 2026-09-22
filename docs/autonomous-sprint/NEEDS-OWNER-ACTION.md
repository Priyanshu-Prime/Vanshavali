# Owner-Action Items — Vanshavali Sprint

Things the autonomous loop **cannot** do itself (need your dashboard access, an
account signup, a credential, or a decision). The loop keeps going without these;
do them whenever you have time. Nothing here blocks other implementation.

**Release plan (your instruction, 2026-09-22):** keep small commits landing on
branches; a single release with everything is cut from `main` only once the whole
sprint is done and tested — for you to test then. No feature-branch releases.

## Pending (fill in / do when convenient)

### Supabase dashboard
- [ ] **Spend cap** — confirm the free-plan spend cap is ON (Settings → Billing) so the
      project can never silently upgrade to a paid tier. (Task #3)
- [ ] **Auth rate limits** — review Auth → Rate Limits (SMS/email/token). Defaults are
      usually fine; note anything you want tightened. (Task #1/#2)
- [ ] **Storage bucket for profile pics** — will be needed for F-A. The loop will draft
      the bucket name + RLS policy as a migration/config; you may need to create the
      bucket or confirm the policy in the dashboard. (Details appended by R-media.)

### Third-party signups (all have free tiers)
- [ ] **Uptime monitor** — pick one (UptimeRobot / cron-job.org / BetterStack free) and
      create an account; the loop will supply the URL(s) to monitor. (Task #17)
- [ ] **Slack log forwarding** — R-infra is researching whether an *individual
      contributor* (non-admin) can create an incoming webhook. If it needs a workspace
      admin to approve the app, that approval is your action. (Task #18) — findings appended below.

### Backups
- [ ] **Backup credentials** — free tier has no PITR. The loop will provide a `pg_dump`
      restore script; running a real backup needs the DB connection string / password
      you hold. (Task #20)

### Carried over from earlier (not part of this sprint but still open)
- [ ] **Phone OTP go-live** — Fast2SMS + DLT registration + deploy send-sms-hook +
      enable phone provider. (See supabase/functions/send-sms-hook/README.md.) The phone
      feature stays on `fix/phone-otp` until this is done.

## Research findings appended by agents

### 🔴 URGENT — free-tier 7-day auto-pause (do this first)
A low-traffic project auto-pauses after 7 days idle. Create **one free UptimeRobot** HTTP
monitor, 5-min interval, that doubles as keep-alive + downtime alert:
1. uptimerobot.com → sign up (free).
2. Add Monitor → HTTP(s) → URL: `https://<PROJECT_REF>.supabase.co/rest/v1/family_members?select=id&limit=1`
3. Under Custom HTTP Headers add: `apikey: <ANON_KEY>` (anon key is already public in the APK).
4. Interval 5 min; add your email as alert contact. Save.
(The loop will also add a tiny `ping()` RPC as an even cleaner target — either works.)

### Migrations to apply in the SQL editor (loop writes the files; you run them) — apply IN ORDER 015→016→017
- **015** (search + keep-alive): pg_trgm + GIN indexes + drop dead name index + `ping()`.
- **016** (profile pics): `avatar_url` column + `avatars` storage bucket + policies. If the
  `storage.buckets` insert errors on `file_size_limit`/`allowed_mime_types`, create the bucket
  `avatars` (Public, 300KB, image/jpeg,png,webp) + its 4 policies in Dashboard → Storage instead.
- **017** (duplicate/claim): `find_duplicate_candidates` RPC + `merge_requests` extension + claim RPCs.
  BUILT (reuses merge_requests via a `kind` column, the least-schema option). A SQL self-check query is
  in the file's trailing comment (known dup scores ≥0.72; gender mismatch excluded).
  ⚠ **Your decision (F-I approver rule):** approving a claim currently reuses `can_edit_family_member`,
  which migration 012 loosened to "any registered member can edit/approve for an unclaimed target" —
  so today ANY member can approve a claim request (matches the app-wide trust model). If you want
  stricter "only a claimed ±1 relative approves", that needs a dedicated kinship check — say so and
  I'll tighten it. `approve/reject` already block self-approval (approver ≠ requester).

### Slack log forwarding
Non-admins usually **cannot** create a Slack incoming webhook (needs workspace app-install approval).
Easiest fix: make a **personal free Slack workspace** (you're admin) and create the webhook there, OR
use a **Discord/Telegram** webhook (no admin gate). Give me the `hooks.slack.com/...` (or Discord) URL;
I'll insert it into a private secrets row and wire the pg_net trigger. Until then the error_logs table
still captures everything (readable via SQL) — Slack is just the push channel.

### Backups (no PITR on free tier)
From Dashboard → Settings → Database copy the **Session pooler** connection string (IPv4 — the direct
5432 host is IPv6-only on free) + DB password. Then a weekly `pg_dump -Fc "<pooler-string>" -f v.dump`
(loop will drop a script in scripts/). Store dumps off-Supabase.

### Load test params (when you want it run)
Supply `SUPABASE_REF`, `ANON_KEY`, and a known `ROOT_MEMBER_ID`; the k6 script runs at ~50 virtual
users (realistic village peak). `get_connected_tree` needs a signed-in JWT or the local e2e stack.

### Prod auth rate limits
config.toml limits are LOCAL only. If magic-link testers get "too many requests", raise `email_sent`
(currently 2/hr) in Dashboard → Authentication → Rate Limits.
