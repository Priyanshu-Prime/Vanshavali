# Backend audit tooling

Reusable scripts for testing the live Supabase backend directly — schema/RLS
introspection, data-integrity checks, and behavioral RLS/RPC tests using
disposable test accounts. Built because manual dashboard round-trips
(write SQL → paste into dashboard → paste results back) don't scale for
thorough backend verification.

## Setup (one-time)

1. Copy `supabase/.env.local.example` to `supabase/.env.local` and fill in:
   - `SUPABASE_DB_URL` — direct Postgres connection string (Project Settings →
     Database → Connection string → URI).
   - `SUPABASE_SERVICE_ROLE_KEY` — Project Settings → API → service_role
     (secret). Bypasses RLS — treat like a root password. Never commit,
     never paste into chat.
   `supabase/.env.local` is gitignored.
2. `cd scripts/backend_audit && npm install`

## What's here

- `schema_and_rls_audit.mjs` — read-only queries: full schema dump, every RLS
  policy on every table, every function/RPC signature, data-integrity checks
  (orphaned father_id/mother_id, duplicate auth_user_id rows, spouse_relationships
  pair_key collisions, orphaned invite codes). Safe to run anytime, changes
  nothing.
- `rls_behavior_test.mjs` — creates disposable test accounts (clearly labeled,
  e.g. `vanshavali-audit-test+<timestamp>@example.invalid`), exercises RLS
  policies and RPCs (claim_profile, claim_profile_by_code, spouse_relationships
  insert/delete, search_family_members) as different authenticated identities
  to confirm allow/deny behavior actually matches what the SQL policies claim,
  then deletes everything it created. Requires both `SUPABASE_DB_URL` (cleanup
  verification) and `SUPABASE_SERVICE_ROLE_KEY` (test-user admin API).

## Running

```
cd scripts/backend_audit
node schema_and_rls_audit.mjs      # read-only report
node rls_behavior_test.mjs         # writes + cleans up disposable test data
```

Both scripts read `../../supabase/.env.local` — never pass credentials on the
command line (shell history) or hardcode them here.
