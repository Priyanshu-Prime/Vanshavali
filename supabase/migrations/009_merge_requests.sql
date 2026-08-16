-- Detect-and-flag handling for the "invitee already has their own claimed
-- profile, AND a relative separately created an unclaimed placeholder for
-- that same real person" collision.
--
-- Both `claim_profile` (001) and `claim_profile_by_code` (002) already
-- refuse to let a user claim a second profile once they have one
-- (`RAISE EXCEPTION 'User already has a profile'`), and the unique index on
-- `family_members.auth_user_id` (006) backstops that at the DB level. That's
-- correct — it stops a hijack/duplicate-auth-link — but it leaves the
-- underlying real-world problem unresolved: the invitee's OWN profile and
-- the placeholder their relative made for them are still two separate
-- `family_members` rows for one real person, with no way to reconcile them
-- except a developer manually running SQL. Previously there wasn't even a
-- record that this happened — the claim just failed into a raw exception
-- string with nothing captured for follow-up.
--
-- This migration adds an audit queue only. It deliberately does NOT attempt
-- automated merging/reassignment of father_id/mother_id/spouse_relationships
-- references from the duplicate onto the real profile — that's a genuinely
-- risky data operation (which relation wins on conflict? what if the
-- duplicate has children of its own?) and out of scope for this pass. A
-- flagged row here is resolved by the project owner running manual SQL
-- directly (see docs/claude_handoff/04_current_risks.md for the exact
-- remediation steps) — no admin UI is built for this either.
--
-- RLS: authenticated users can INSERT a row about themselves (and only
-- about themselves — verified via the existing_profile_id ownership check,
-- same EXISTS-against-family_members pattern used throughout this schema).
-- No SELECT/UPDATE/DELETE policy exists for regular users at all — this is
-- an admin-only queue, read/resolved directly via the Supabase SQL Editor
-- (service-role access bypasses RLS entirely, same as error_logs in 008).

BEGIN;

CREATE TABLE IF NOT EXISTS public.merge_requests (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  requested_by_auth_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  -- The invitee's own already-claimed profile.
  existing_profile_id UUID REFERENCES public.family_members(id) ON DELETE SET NULL,
  -- The unclaimed placeholder row they were trying to claim when the
  -- "already has a profile" guard rejected them.
  duplicate_placeholder_id UUID REFERENCES public.family_members(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'resolved', 'dismissed')),
  resolved_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_merge_requests_status_pending
  ON public.merge_requests(status)
  WHERE status = 'pending';

ALTER TABLE public.merge_requests ENABLE ROW LEVEL SECURITY;

-- Defense in depth: the app always goes through the flag_duplicate_for_merge
-- RPC below (SECURITY DEFINER, bypasses RLS), but this policy exists so a
-- direct client insert can't be used to log a merge request against
-- someone else's profile.
CREATE POLICY "Users can flag a duplicate against their own profile"
  ON public.merge_requests
  FOR INSERT
  TO authenticated
  WITH CHECK (
    requested_by_auth_user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.family_members fm
      WHERE fm.id = merge_requests.existing_profile_id
        AND fm.auth_user_id = auth.uid()
    )
  );

-- No SELECT/UPDATE/DELETE policy for `authenticated` — intentional. This
-- queue is read and resolved only via the Supabase SQL Editor (service-role
-- access), not from the app.

-- ============================================
-- RPC: flag_duplicate_for_merge
-- ============================================
-- Called by the app when claim_profile/claim_profile_by_code fails with
-- "User already has a profile" — records the conflict for manual review
-- instead of letting it just error into the void. Re-derives the caller's
-- own profile id server-side (never trusts a client-supplied value for
-- existing_profile_id) and verifies the target is a genuine unclaimed
-- placeholder before logging anything.
CREATE OR REPLACE FUNCTION public.flag_duplicate_for_merge(duplicate_placeholder_id UUID)
RETURNS public.merge_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  caller_profile_id UUID;
  result public.merge_requests;
BEGIN
  SELECT id INTO caller_profile_id
  FROM public.family_members
  WHERE auth_user_id = auth.uid();

  IF caller_profile_id IS NULL THEN
    RAISE EXCEPTION 'Calling user has no claimed profile of their own to flag a duplicate against';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.family_members
    WHERE id = duplicate_placeholder_id AND auth_user_id IS NULL
  ) THEN
    RAISE EXCEPTION 'Target profile not found or is not an unclaimed placeholder';
  END IF;

  INSERT INTO public.merge_requests (
    requested_by_auth_user_id,
    existing_profile_id,
    duplicate_placeholder_id
  ) VALUES (
    auth.uid(),
    caller_profile_id,
    duplicate_placeholder_id
  )
  RETURNING * INTO result;

  RETURN result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.flag_duplicate_for_merge(UUID) TO authenticated;

COMMIT;
