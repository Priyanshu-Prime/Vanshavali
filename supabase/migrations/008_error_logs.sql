-- Lightweight, zero-cost crash/error reporting. The app has had zero crash
-- visibility so far — every bug found this project's life so far was found
-- by manual on-device testing, not by a real user's report. This is an
-- in-house alternative to a third-party service (Sentry etc.) to stay
-- within the project's strict zero-cost constraint: write-only from the
-- app's perspective, no read policy at all (not even the reporting user can
-- read entries back — this is a write sink for developers to query
-- directly via the SQL editor, not an in-app feature).
--
-- Granted to anon as well as authenticated: a crash can happen before
-- login (e.g. on the login screen itself), and reads requiring auth
-- (migration 006) shouldn't also block error *reporting* pre-login.

BEGIN;

CREATE TABLE IF NOT EXISTS public.error_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  auth_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  error_message TEXT NOT NULL,
  stack_trace TEXT,
  context TEXT,
  platform TEXT
);

ALTER TABLE public.error_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can report an error"
  ON public.error_logs
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (auth_user_id IS NULL OR auth_user_id = auth.uid());

GRANT INSERT ON public.error_logs TO anon, authenticated;

COMMIT;
