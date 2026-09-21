# Research: infra / hardening (tasks 1-3, 11-13, 17-20)

Status: RESEARCHED (2026-09-22). Reality check: at ~500 users the DB is tiny; FKs are
already indexed. Most "optimisation" is low-value insurance. Genuinely worth doing:
pg_trgm search index, keep-alive ping (7-day auto-pause is imminent), backups, Slack pipe.

## Already indexed — DO NOT re-create
father_id, mother_id (001); auth_user_id partial-unique (006); village_origin btree (001,
exact-match only); spouse member/spouse (003); invite_code (002). `get_ego_network`,
`get_ancestor_chain`, `get_connected_tree`, `getChildren`, `getCurrentUserProfile` all covered.

## #11/#12 — the ONE real gap: search. DRAFT migration 015 (indexes only)
`search_family_members` uses `ILIKE '%q%'` on 6 columns → no btree can serve it; needs pg_trgm.
```sql
BEGIN;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX IF NOT EXISTS idx_fm_trgm_first_en ON public.family_members USING gin (first_name_en gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_fm_trgm_last_en  ON public.family_members USING gin (last_name_en  gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_fm_trgm_first_gu ON public.family_members USING gin (first_name_gu gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_fm_trgm_last_gu  ON public.family_members USING gin (last_name_gu  gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_fm_trgm_village  ON public.family_members USING gin (village_origin gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_fm_trgm_city     ON public.family_members USING gin (current_city  gin_trgm_ops);
DROP INDEX IF EXISTS idx_family_members_names;  -- dead: btree can't serve the ILIKE search
COMMIT;
```
(Avatar migration from profile-pic.md must therefore be 016, not 015.)

## #13 — pagination. SCOPING CORRECTION for F-E
Directory today = `get_connected_tree(myId)` filtered in-memory (fast, offline, right at 500).
`config.toml max_rows=1000` hard-caps any payload; `getAllFamilyMembers` (supabase_service.dart:504,
full-sync) silently truncates past 1000. **F-E "All" tab (entire DB) needs a NEW keyset-paginated
RPC** `get_all_members_page(after_last, after_id, page_size)` + infinite scroll. "My family" tab = the
existing connected-tree in-memory list. So F-E is bigger than "add tabs".

## #1/#3 — rate limiting
config.toml [auth.rate_limit] governs LOCAL only (prod = Dashboard, or `supabase config push`).
`email_sent=2/hr` is tight for magic-link — raise on prod if testers get blocked (OWNER).
**Client gap:** `searchMembers` (family_provider.dart:337) has NO debounce/in-flight guard — the one
typed path that hits the server per call. Add 300-400ms debounce + drop-stale guard, reusing the
existing 500ms Timer pattern (add_family_member_screen.dart:300, profile_form_screen.dart:127).

## #17 — keep-alive + uptime (URGENT: 7-day auto-pause)
Add 1-line `SECURITY DEFINER ping() returns timestamptz` granted to anon; OWNER creates ONE free
UptimeRobot HTTP monitor @5min hitting `/rest/v1/rpc/ping?apikey=<ANON>` (or
`/rest/v1/family_members?select=id&limit=1` with apikey header). Doubles as keep-alive + downtime alert.

## #18 — error_logs → Slack (error_logs already exists, 008)
Non-admin usually CANNOT create a Slack webhook (needs workspace app-install approval). Fallbacks:
personal free Slack workspace (you're admin), or Discord/Telegram webhook (no admin gate). Wiring:
pg_net AFTER-INSERT trigger on error_logs building Slack `{"text":...}` payload; webhook URL stored in a
`private.app_secrets` row (NOT committed SQL), trigger no-ops if absent. DEFER build until OWNER has a
webhook URL. (Ponytail: don't build the pipe before there's a sink.)

## #20 — backups (no PITR on free tier)
`supabase db dump --linked -f backup.sql` or `pg_dump -Fc "<session-pooler-IPv4-string>" -f v.dump`;
restore `pg_restore --clean --if-exists`. OWNER supplies the **Session-pooler** connection string
(IPv4; direct 5432 is IPv6-only on free) + DB password. Schedule weekly.

## #19 — load test
k6 (not Dart). ~50 VUs (village realistic peak, not 500 — else you test Supabase's throttle). Skeleton
saved to scripts/ later; hits get_ego_network (anon-granted) + get_connected_tree (needs a JWT or the
local e2e stack). OWNER supplies REF, ANON_KEY, ROOT_MEMBER_ID.

## Ranked (value/effort)
1. keep-alive ping() RPC + owner monitor  2. searchMembers debounce  3. error_logs→Slack (owner webhook first)
4. backup routine  5. migration 015 trgm + drop dead index  6. keyset pagination (for F-E All tab)  7. k6 script.
