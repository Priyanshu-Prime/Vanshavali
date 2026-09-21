-- 015_search_and_keepalive.sql
--
-- Two independent hardening changes:
--
-- 1. SEARCH PERF. search_family_members() matches names/village/city with ILIKE
--    '%q%'. A plain btree index (idx_family_members_names, from 001) cannot serve
--    a leading-wildcard ILIKE, so those searches were sequential scans over the
--    whole table. pg_trgm + GIN trigram indexes are the correct structure for
--    substring/ILIKE matching, so we add one per searchable text column and drop
--    the dead btree that was only ever a full-table scan for this query.
--    (pg_trgm ships with Postgres on the Supabase free tier — no cost.)
--
-- 2. KEEP-ALIVE. Supabase free-tier projects auto-pause after ~7 days with no
--    activity, adding a cold-start delay for the next user. ping() is a trivial
--    anon-callable RPC an external uptime monitor (e.g. UptimeRobot -> rpc/ping)
--    can hit on a schedule to keep the project warm. SECURITY DEFINER + a pinned
--    search_path so it runs regardless of caller privileges without exposing
--    anything but now().
--
-- Existing indexes NOT recreated here (confirmed against 001/002/003/006):
--   idx_family_members_names (btree) is DROPPED below; all idx_fm_trgm_* are new.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS idx_fm_trgm_first_en ON public.family_members USING gin (first_name_en gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_fm_trgm_last_en  ON public.family_members USING gin (last_name_en  gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_fm_trgm_first_gu ON public.family_members USING gin (first_name_gu gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_fm_trgm_last_gu  ON public.family_members USING gin (last_name_gu  gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_fm_trgm_village  ON public.family_members USING gin (village_origin gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_fm_trgm_city     ON public.family_members USING gin (current_city  gin_trgm_ops);

DROP INDEX IF EXISTS idx_family_members_names;  -- dead: btree can't serve the ILIKE search

-- keep-alive / uptime target: touches Postgres, callable anonymously
CREATE OR REPLACE FUNCTION public.ping() RETURNS timestamptz
  LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$ SELECT now(); $$;
GRANT EXECUTE ON FUNCTION public.ping() TO anon, authenticated;

COMMIT;
