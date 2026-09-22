-- 017: Duplicate detection -> claim request.
--
-- Two capabilities, both reuse-heavy (see docs/autonomous-sprint/research/
-- claim-system.md):
--
--  1. find_duplicate_candidates(): given the details a user just typed (their
--     own onboarding profile, or a new relative they're about to create),
--     return the existing rows that look like the same real person, with a
--     weighted trigram score. This is a READ-ONLY heuristic to catch the
--     "someone already added a placeholder for me / this relative" case BEFORE
--     a second duplicate row is created.
--
--  2. request_claim / approve_claim_request / reject_claim_request(): a
--     claimer-initiated, human-approved claim of an unclaimed placeholder that
--     was found by matching (NOT via an invite). Unlike claim_profile (001,
--     invite-authorized, instant), a match-found claim has no proof the caller
--     is that person, so it REQUIRES an approval step by an eligible member --
--     otherwise it's claim-jacking. That approval step is the whole reason a
--     "claim request" exists rather than calling claim_profile directly.
--
-- SCHEMA REUSE: the claim workflow is layered onto merge_requests (009) rather
-- than a new table -- kind='claim_request' + target_profile_id. See the OWNER
-- DECISION note in the research doc: overloading one table with two workflows
-- is a "one table, two meanings" smell; default here is reuse (least new
-- schema), switch to a dedicated claim_requests table only if they diverge.
--
-- INDEXES: pg_trgm + the family_members name/village GIN indexes already exist
-- (migration 015). This migration does NOT recreate them. At ~500 rows the
-- scoring below is a trivial sequential scan regardless; the indexes matter
-- only once the village grows.
--   ponytail: O(n) scan per detection call, fine at village scale (<1k rows);
--   push the trigram `%` prefilter down to the WHERE if it ever gets slow.

BEGIN;

-- ============================================================
-- Part 1 -- Duplicate candidate matching
-- ============================================================
-- Weighted score in [~ -0.1, 1.0] (dob penalty can push slightly negative):
--   name 0.40 (GREATEST of en/gu full-name trigram similarity)
--   father 0.20, mother 0.15 (trigram sim of the linked parent's name vs the
--     parent name derivable from the add-relative context; 0 if not supplied)
--   village 0.10 (1.0 exact / 0.5 partial)
--   dob 0.10 (1.0 exact / 0.6 within +-1yr / -0.5 if differ by >2yr)
--   gender 0.05 (equal only; HARD-EXCLUDED in WHERE on a real mismatch)
-- Threshold >= 0.45. Returns the full candidate row (as jsonb, so the Dart
-- side reuses FamilyMember.fromJson) plus the score and the sub-scores.
CREATE OR REPLACE FUNCTION public.find_duplicate_candidates(
  p_first_name_en TEXT,
  p_last_name_en  TEXT,
  p_first_name_gu TEXT DEFAULT NULL,
  p_last_name_gu  TEXT DEFAULT NULL,
  p_gender        TEXT DEFAULT NULL,
  p_dob           DATE DEFAULT NULL,
  p_village       TEXT DEFAULT NULL,
  p_father_name   TEXT DEFAULT NULL,
  p_mother_name   TEXT DEFAULT NULL,
  p_exclude_id    UUID DEFAULT NULL,
  p_limit         INT  DEFAULT 10
)
RETURNS TABLE (member JSONB, score REAL, sub_scores JSONB)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  WITH target AS (
    SELECT
      lower(trim(coalesce(p_first_name_en, '') || ' ' || coalesce(p_last_name_en, ''))) AS name_en,
      NULLIF(lower(trim(coalesce(p_first_name_gu, '') || ' ' || coalesce(p_last_name_gu, ''))), '') AS name_gu
  ),
  scored AS (
    SELECT
      fm.id,
      -- name: best of en/gu full-name similarity
      GREATEST(
        similarity(lower(fm.first_name_en || ' ' || fm.last_name_en), t.name_en),
        CASE WHEN t.name_gu IS NOT NULL AND fm.first_name_gu IS NOT NULL
             THEN similarity(lower(coalesce(fm.first_name_gu, '') || ' ' || coalesce(fm.last_name_gu, '')), t.name_gu)
             ELSE 0 END
      )::REAL AS name_score,
      -- father: sim of the linked father's name vs the supplied parent name
      CASE WHEN p_father_name IS NULL OR fa.id IS NULL THEN 0
           ELSE GREATEST(
             similarity(lower(fa.first_name_en || ' ' || fa.last_name_en), lower(p_father_name)),
             CASE WHEN fa.first_name_gu IS NOT NULL
                  THEN similarity(lower(coalesce(fa.first_name_gu, '') || ' ' || coalesce(fa.last_name_gu, '')), lower(p_father_name))
                  ELSE 0 END)
      END::REAL AS father_score,
      CASE WHEN p_mother_name IS NULL OR mo.id IS NULL THEN 0
           ELSE GREATEST(
             similarity(lower(mo.first_name_en || ' ' || mo.last_name_en), lower(p_mother_name)),
             CASE WHEN mo.first_name_gu IS NOT NULL
                  THEN similarity(lower(coalesce(mo.first_name_gu, '') || ' ' || coalesce(mo.last_name_gu, '')), lower(p_mother_name))
                  ELSE 0 END)
      END::REAL AS mother_score,
      CASE WHEN p_village IS NULL OR fm.village_origin IS NULL THEN 0
           WHEN lower(fm.village_origin) = lower(p_village) THEN 1.0
           WHEN similarity(lower(fm.village_origin), lower(p_village)) >= 0.5 THEN 0.5
           ELSE 0 END::REAL AS village_score,
      CASE WHEN p_dob IS NULL OR fm.dob IS NULL THEN 0
           WHEN fm.dob = p_dob THEN 1.0
           WHEN abs(fm.dob - p_dob) <= 366 THEN 0.6
           WHEN abs(fm.dob - p_dob) > 730 THEN -0.5
           ELSE 0 END::REAL AS dob_score,
      CASE WHEN p_gender IS NOT NULL AND fm.gender = p_gender THEN 1.0
           ELSE 0 END::REAL AS gender_score
    FROM public.family_members fm
    CROSS JOIN target t
    LEFT JOIN public.family_members fa ON fa.id = fm.father_id
    LEFT JOIN public.family_members mo ON mo.id = fm.mother_id
    WHERE (p_exclude_id IS NULL OR fm.id <> p_exclude_id)
      -- HARD gender exclude: only when BOTH are known and differ.
      AND (p_gender IS NULL OR fm.gender IS NULL OR fm.gender = p_gender)
  ),
  totalled AS (
    SELECT
      s.id,
      (0.40 * s.name_score + 0.20 * s.father_score + 0.15 * s.mother_score
        + 0.10 * s.village_score + 0.10 * s.dob_score + 0.05 * s.gender_score)::REAL AS score,
      s.name_score, s.father_score, s.mother_score,
      s.village_score, s.dob_score, s.gender_score
    FROM scored s
  )
  SELECT
    to_jsonb(fm.*) AS member,
    tt.score,
    jsonb_build_object(
      'name', tt.name_score, 'father', tt.father_score, 'mother', tt.mother_score,
      'village', tt.village_score, 'dob', tt.dob_score, 'gender', tt.gender_score
    ) AS sub_scores
  FROM totalled tt
  JOIN public.family_members fm ON fm.id = tt.id
  WHERE tt.score >= 0.45
  ORDER BY tt.score DESC
  LIMIT p_limit;
$$;

GRANT EXECUTE ON FUNCTION public.find_duplicate_candidates(
  TEXT, TEXT, TEXT, TEXT, TEXT, DATE, TEXT, TEXT, TEXT, UUID, INT
) TO authenticated;

-- ============================================================
-- Part 2 -- Extend merge_requests for the claim workflow
-- ============================================================
ALTER TABLE public.merge_requests
  ADD COLUMN IF NOT EXISTS kind TEXT NOT NULL DEFAULT 'auto_flag'
    CHECK (kind IN ('auto_flag', 'claim_request'));

ALTER TABLE public.merge_requests
  ADD COLUMN IF NOT EXISTS target_profile_id UUID
    REFERENCES public.family_members(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_merge_requests_claim_pending
  ON public.merge_requests(target_profile_id)
  WHERE kind = 'claim_request' AND status = 'pending';

-- SELECT policy: an eligible approver may read pending claim requests they can
-- act on. Eligibility = can_edit_family_member(target) (migration 012: any
-- member who has a profile of their own, for an unclaimed target) AND the
-- approver is not the requester. This is the app-wide trust model (012); the
-- research doc's stated intent was a tighter "claimed +-1 relative", which
-- 012 loosened -- see OWNER note in the report. The approve/reject RPCs below
-- re-enforce this same guard, so this policy is defense-in-depth for the
-- pending_claim_requests read path.
DROP POLICY IF EXISTS "Approvers can read claim requests" ON public.merge_requests;
CREATE POLICY "Approvers can read claim requests"
  ON public.merge_requests
  FOR SELECT
  TO authenticated
  USING (
    kind = 'claim_request'
    AND requested_by_auth_user_id <> auth.uid()
    AND public.can_edit_family_member(target_profile_id)
  );

-- ============================================================
-- Part 3 -- Claim request RPCs (SECURITY DEFINER)
-- ============================================================

-- request_claim: a profile-less user asks to claim an unclaimed placeholder
-- that a match surfaced. Idempotent -- re-requesting the same target returns
-- the existing pending row rather than stacking duplicates.
CREATE OR REPLACE FUNCTION public.request_claim(target UUID)
RETURNS public.merge_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid    UUID := auth.uid();
  result public.merge_requests;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Caller must not already have a profile (claim_profile's one-profile rule).
  IF EXISTS (SELECT 1 FROM public.family_members WHERE auth_user_id = uid) THEN
    RAISE EXCEPTION 'You already have a profile';
  END IF;

  -- Target must exist and be an unclaimed placeholder.
  IF NOT EXISTS (
    SELECT 1 FROM public.family_members WHERE id = target AND auth_user_id IS NULL
  ) THEN
    RAISE EXCEPTION 'Target profile not found or already claimed';
  END IF;

  -- Reuse an existing pending request for the same (requester, target).
  SELECT * INTO result
  FROM public.merge_requests
  WHERE kind = 'claim_request'
    AND status = 'pending'
    AND requested_by_auth_user_id = uid
    AND target_profile_id = target
  LIMIT 1;
  IF FOUND THEN
    RETURN result;
  END IF;

  INSERT INTO public.merge_requests (
    requested_by_auth_user_id, target_profile_id, kind
  ) VALUES (uid, target, 'claim_request')
  RETURNING * INTO result;

  RETURN result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.request_claim(UUID) TO authenticated;

-- approve_claim_request: an eligible approver grants a pending claim. Sets the
-- target's auth_user_id to the requester (the unique index from 006 backstops
-- against a double-claim). Never the requester themselves.
CREATE OR REPLACE FUNCTION public.approve_claim_request(request_id UUID)
RETURNS public.family_members
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid    UUID := auth.uid();
  req    public.merge_requests;
  result public.family_members;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO req FROM public.merge_requests
  WHERE id = request_id AND kind = 'claim_request' AND status = 'pending';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Claim request not found or already resolved';
  END IF;

  IF req.requested_by_auth_user_id = uid THEN
    RAISE EXCEPTION 'You cannot approve your own claim request';
  END IF;

  -- Approver must be allowed to edit the target (kinship / trust gate).
  IF NOT public.can_edit_family_member(req.target_profile_id) THEN
    RAISE EXCEPTION 'You are not allowed to approve this claim';
  END IF;

  -- Re-check the target is still an unclaimed placeholder.
  IF NOT EXISTS (
    SELECT 1 FROM public.family_members
    WHERE id = req.target_profile_id AND auth_user_id IS NULL
  ) THEN
    RAISE EXCEPTION 'Target profile is no longer claimable';
  END IF;

  -- Re-check the requester still has no profile.
  IF EXISTS (
    SELECT 1 FROM public.family_members WHERE auth_user_id = req.requested_by_auth_user_id
  ) THEN
    RAISE EXCEPTION 'Requester already has a profile';
  END IF;

  UPDATE public.family_members
  SET auth_user_id = req.requested_by_auth_user_id
  WHERE id = req.target_profile_id AND auth_user_id IS NULL
  RETURNING * INTO result;

  UPDATE public.merge_requests
  SET status = 'resolved', resolved_at = now()
  WHERE id = request_id;

  RETURN result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.approve_claim_request(UUID) TO authenticated;

-- reject_claim_request: an eligible approver dismisses a pending claim.
CREATE OR REPLACE FUNCTION public.reject_claim_request(request_id UUID)
RETURNS public.merge_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid    UUID := auth.uid();
  req    public.merge_requests;
  result public.merge_requests;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO req FROM public.merge_requests
  WHERE id = request_id AND kind = 'claim_request' AND status = 'pending';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Claim request not found or already resolved';
  END IF;

  IF req.requested_by_auth_user_id = uid THEN
    RAISE EXCEPTION 'You cannot reject your own claim request';
  END IF;

  IF NOT public.can_edit_family_member(req.target_profile_id) THEN
    RAISE EXCEPTION 'You are not allowed to reject this claim';
  END IF;

  UPDATE public.merge_requests
  SET status = 'dismissed', resolved_at = now()
  WHERE id = request_id
  RETURNING * INTO result;

  RETURN result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.reject_claim_request(UUID) TO authenticated;

-- pending_claim_requests: the approver inbox. Returns pending claim requests
-- the caller is eligible to approve, with the target row (as jsonb) for
-- rendering. SECURITY DEFINER so can_edit_family_member's internal reads run
-- as owner; the eligibility filter mirrors the SELECT policy above.
CREATE OR REPLACE FUNCTION public.pending_claim_requests()
RETURNS TABLE (request_id UUID, created_at TIMESTAMPTZ, requester UUID, target JSONB)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT mr.id, mr.created_at, mr.requested_by_auth_user_id, to_jsonb(fm.*)
  FROM public.merge_requests mr
  JOIN public.family_members fm ON fm.id = mr.target_profile_id
  WHERE mr.kind = 'claim_request'
    AND mr.status = 'pending'
    AND mr.requested_by_auth_user_id <> auth.uid()
    AND public.can_edit_family_member(mr.target_profile_id)
  ORDER BY mr.created_at DESC;
$$;

GRANT EXECUTE ON FUNCTION public.pending_claim_requests() TO authenticated;

COMMIT;

-- ============================================================
-- SQL self-check (run manually in the SQL editor; not part of the migration)
-- ============================================================
-- Given two rows for "Ramesh Patel" (same village + dob), a lookup with those
-- details should score >= 0.72; a gender-mismatched row must be excluded:
--   SELECT score, member->>'first_name_en'
--   FROM find_duplicate_candidates('Ramesh','Patel', p_gender=>'Male',
--        p_village=>'Anand', p_dob=>'1980-01-01');
-- Expect the matching Male row high, no Female row returned at all.
