# Vanshavali E2E test rig

Runs the **real app** on an Android emulator against a **real local Supabase**
(full Postgres + Auth + RLS + your actual migrations). This is what catches the
backend-seam bugs the mock-based unit tests under `test/` cannot see — signup
session handling, RLS, single-use invite codes, navigation dead-ends, etc.

## One-time setup
1. **Docker Desktop** installed and running.
2. **Android emulator image** (large download):
   ```
   "$LOCALAPPDATA/Android/Sdk/cmdline-tools/latest/bin/sdkmanager.bat" \
     "platform-tools" "emulator" "system-images;android-34;google_apis;x86_64"
   ```
3. **Local Supabase** (pulls images on first run):
   ```
   npx supabase start
   ```

## Each run
```bash
# 1. Boot the emulator (creates the AVD on first run, then reuses it).
scripts/e2e/start_emulator.sh

# 2. Reset the DB + run the whole suite (or pass one test file).
scripts/e2e/run_e2e.sh
scripts/e2e/run_e2e.sh integration_test/flows/signup_claim_test.dart
```

`run_e2e.sh` resets the local DB (re-applies migrations + `supabase/seed.sql`),
reads the local Supabase URL/anon key, rewrites the URL to `10.0.2.2` (how the
emulator reaches the host), and runs the tests against that backend.

## Layout
- `integration_test/harness.dart` — boots the real app, clean slate per test,
  and small helpers (`enterInField`, `tapText`).
- `integration_test/smoke_test.dart` — proves the plumbing (app boots, reaches
  Login / onboarding).
- `integration_test/flows/` — one file per user flow.
- `supabase/seed.sql` — deterministic unclaimed placeholders with known invite
  codes (`TEST01`–`TEST04`).
- `docs/test_scenarios.md` — **the steering document**: edit it to change what
  gets tested.

## What stays manual
Real email deliverability, Play Store deferred deep links, and real-device
rendering — see the `MANUAL` rows in `docs/test_scenarios.md`.
