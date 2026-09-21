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
_(agents append feasibility notes + exact steps here)_
