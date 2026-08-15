-- Add invite_code column for code-based profile claiming
-- A short 6-character alphanumeric code generated when a member is invited

ALTER TABLE public.family_members
  ADD COLUMN IF NOT EXISTS invite_code TEXT UNIQUE;

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_family_members_invite_code
  ON public.family_members(invite_code)
  WHERE invite_code IS NOT NULL;

-- RPC Function: Claim profile by invite code
CREATE OR REPLACE FUNCTION claim_profile_by_code(code TEXT)
RETURNS public.family_members
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result public.family_members;
BEGIN
  -- Check if user already has a profile
  IF EXISTS (SELECT 1 FROM public.family_members WHERE auth_user_id = auth.uid()) THEN
    RAISE EXCEPTION 'User already has a profile';
  END IF;

  -- Find and claim the profile by invite code
  UPDATE public.family_members
  SET auth_user_id = auth.uid(),
      invite_code = NULL  -- Clear the code after claiming
  WHERE invite_code = code AND auth_user_id IS NULL
  RETURNING * INTO result;

  IF result IS NULL THEN
    RAISE EXCEPTION 'Invalid or already claimed invite code';
  END IF;

  RETURN result;
END;
$$;

-- RPC Function: Look up member by invite code (read-only, for preview)
CREATE OR REPLACE FUNCTION get_member_by_invite_code(code TEXT)
RETURNS public.family_members
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result public.family_members;
BEGIN
  SELECT * INTO result
  FROM public.family_members
  WHERE invite_code = code AND auth_user_id IS NULL;

  RETURN result;
END;
$$;

GRANT EXECUTE ON FUNCTION claim_profile_by_code(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_member_by_invite_code(TEXT) TO anon, authenticated;
