-- 018: Claim + link hardening (fixes for F-I / migration 017 audit findings).
--
-- Idempotent: every object is CREATE OR REPLACE / DROP ... IF EXISTS, so this
-- file can be re-run safely. Does not edit 001-017.
--
--  Part 1  set_member_parents (011) no longer OVERWRITES an existing parent.
--          011 used COALESCE(p_father, father_id), so linking a duplicate match
--          as "child"/"sibling" silently replaced that person's real father/
--          mother. Now: writing a slot that already holds a DIFFERENT parent
--          raises 'vanshavali_parent_already_set'; same value = no-op.
--  Part 2  find_duplicate_candidates (017): name + gender alone (score 0.45)
--          no longer counts as a match -- at least one corroborating signal
--          (village, dob, or a parent name) is required. Signature and return
--          shape unchanged. search_path now includes `extensions` so
--          similarity() resolves wherever pg_trgm is installed.
--  Part 3  is_claim_approver(): claim requests can only be seen/approved/
--          rejected by registered close relatives of the placeholder, not by
--          any member (017 reused 012's "anyone with a profile" rule).
--  Part 4  pending_claim_requests() also returns requester_email so the
--          approver can see WHO is asking.

BEGIN;

-- ============================================================
-- Part 1 -- set_member_parents: never overwrite an existing parent
-- ============================================================
CREATE OR REPLACE FUNCTION public.set_member_parents(
  p_child  UUID,
  p_father UUID DEFAULT NULL,
  p_mother UUID DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid   UUID := auth.uid();
  child public.family_members;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.family_members WHERE auth_user_id = uid) THEN
    RAISE EXCEPTION 'Caller has no profile';
  END IF;

  -- FOR UPDATE: the guard below must see the committed value it overwrites.
  SELECT * INTO child FROM public.family_members WHERE id = p_child FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Target member not found';
  END IF;

  IF child.auth_user_id IS NOT NULL AND child.auth_user_id <> uid THEN
    RAISE EXCEPTION 'Cannot modify a claimed profile you do not own';
  END IF;

  -- Father/mother are one-to-one: filling an EMPTY slot or re-setting the same
  -- value is fine; replacing a different existing parent is never done here.
  IF p_father IS NOT NULL AND child.father_id IS NOT NULL
     AND child.father_id <> p_father THEN
    RAISE EXCEPTION 'vanshavali_parent_already_set: member % already has a different father', p_child;
  END IF;
  IF p_mother IS NOT NULL AND child.mother_id IS NOT NULL
     AND child.mother_id <> p_mother THEN
    RAISE EXCEPTION 'vanshavali_parent_already_set: member % already has a different mother', p_child;
  END IF;

  UPDATE public.family_members
     SET father_id = COALESCE(p_father, father_id),
         mother_id = COALESCE(p_mother, mother_id)
   WHERE id = p_child;
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_member_parents(UUID, UUID, UUID) TO authenticated;

-- ============================================================
-- Part 2 -- find_duplicate_candidates: require a corroborating signal
-- ============================================================
-- Same weights/score as 017. New rule: score >= 0.45 AND at least one of
--   village_score > 0 (exact or partial village match)
--   dob_score > 0     (same dob or within +-1yr)
--   father_score >= 0.5 OR mother_score >= 0.5 (parent name matches)
-- AND the first name itself must be similar (first_score >= 0.3), so a
-- sibling sharing surname/parents/village is never offered as a duplicate,
-- so "Ramesh Patel, Male" alone never surfaces someone else's profile.
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
-- pg_trgm may live in `public` (local) or `extensions` (hosted Supabase);
-- a missing schema in search_path is ignored, so this resolves either way.
SET search_path = public, extensions
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
      GREATEST(
        similarity(lower(fm.first_name_en || ' ' || fm.last_name_en), t.name_en),
        CASE WHEN t.name_gu IS NOT NULL AND fm.first_name_gu IS NOT NULL
             THEN similarity(lower(coalesce(fm.first_name_gu, '') || ' ' || coalesce(fm.last_name_gu, '')), t.name_gu)
             ELSE 0 END
      )::REAL AS name_score,
      -- First name on its own: the full-name score is inflated by a shared
      -- surname, so a SIBLING (same surname, parents, village) would score as
      -- the "same person" -- seen on-device: adding child "Mira Patel" offered
      -- her sister "Kavya Patel". The person's own name must match.
      GREATEST(
        similarity(lower(fm.first_name_en), lower(coalesce(p_first_name_en, ''))),
        CASE WHEN p_first_name_gu IS NOT NULL AND fm.first_name_gu IS NOT NULL
             THEN similarity(lower(fm.first_name_gu), lower(p_first_name_gu))
             ELSE 0 END
      )::REAL AS first_score,
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
      AND (p_gender IS NULL OR fm.gender IS NULL OR fm.gender = p_gender)
  ),
  totalled AS (
    SELECT
      s.id,
      (0.40 * s.name_score + 0.20 * s.father_score + 0.15 * s.mother_score
        + 0.10 * s.village_score + 0.10 * s.dob_score + 0.05 * s.gender_score)::REAL AS score,
      s.name_score, s.first_score, s.father_score, s.mother_score,
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
    AND tt.first_score >= 0.3
    AND (tt.village_score > 0 OR tt.dob_score > 0
         OR tt.father_score >= 0.5 OR tt.mother_score >= 0.5)
  ORDER BY tt.score DESC
  LIMIT p_limit;
$$;

GRANT EXECUTE ON FUNCTION public.find_duplicate_candidates(
  TEXT, TEXT, TEXT, TEXT, TEXT, DATE, TEXT, TEXT, TEXT, UUID, INT
) TO authenticated;

-- ============================================================
-- Part 3 -- is_claim_approver: only close, registered relatives approve
-- ============================================================
-- 017 gated approval on can_edit_family_member (012), which is TRUE for ANY
-- member with a profile when the target is unclaimed -- i.e. any villager
-- could hand anyone's placeholder to a stranger. Approval now needs kinship:
--   ring 1: parents, children, siblings (share a parent), spouses.
--   ring 2 (only if nobody in ring 1 is registered): grandparents,
--           grandchildren, aunts/uncles.
--   ring 3 (only if nobody in rings 1-2 is registered): whoever created the
--           placeholder (activity_log INSERT, 010) -- so a claim on a remote
--           placeholder is never stuck with no possible approver.
-- Target must still be unclaimed. Requester != caller is enforced by callers.
-- Every lookup is keyed on the target's own ids (indexed), never a village scan.
CREATE OR REPLACE FUNCTION public.is_claim_approver(p_target UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  WITH me AS (
    SELECT id FROM public.family_members WHERE auth_user_id = auth.uid()
  ),
  t AS (
    SELECT * FROM public.family_members
    WHERE id = p_target AND auth_user_id IS NULL
  ),
  ring1 AS (
    SELECT fm.id, fm.auth_user_id
    FROM t JOIN public.family_members fm
      ON fm.id <> t.id
     AND (fm.id = t.father_id OR fm.id = t.mother_id
          OR fm.father_id = t.id OR fm.mother_id = t.id
          OR (t.father_id IS NOT NULL AND fm.father_id = t.father_id)
          OR (t.mother_id IS NOT NULL AND fm.mother_id = t.mother_id))
    UNION
    SELECT fm.id, fm.auth_user_id
    FROM t
    JOIN public.spouse_relationships sr ON t.id IN (sr.member_id, sr.spouse_id)
    JOIN public.family_members fm
      ON fm.id = CASE WHEN sr.member_id = t.id THEN sr.spouse_id ELSE sr.member_id END
  ),
  ring2 AS (
    -- grandparents
    SELECT gp.id, gp.auth_user_id
    FROM t
    JOIN public.family_members p ON p.id = t.father_id OR p.id = t.mother_id
    JOIN public.family_members gp ON gp.id = p.father_id OR gp.id = p.mother_id
    UNION
    -- grandchildren
    SELECT gc.id, gc.auth_user_id
    FROM t
    JOIN public.family_members c ON c.father_id = t.id OR c.mother_id = t.id
    JOIN public.family_members gc ON gc.father_id = c.id OR gc.mother_id = c.id
    UNION
    -- aunts/uncles (siblings of a parent)
    SELECT au.id, au.auth_user_id
    FROM t
    JOIN public.family_members p ON p.id = t.father_id OR p.id = t.mother_id
    JOIN public.family_members au
      ON au.id <> p.id
     AND ((p.father_id IS NOT NULL AND au.father_id = p.father_id)
          OR (p.mother_id IS NOT NULL AND au.mother_id = p.mother_id))
  )
  SELECT CASE
    WHEN NOT EXISTS (SELECT 1 FROM t) OR NOT EXISTS (SELECT 1 FROM me) THEN FALSE
    WHEN EXISTS (SELECT 1 FROM ring1 WHERE auth_user_id IS NOT NULL)
      THEN EXISTS (SELECT 1 FROM ring1 JOIN me ON me.id = ring1.id)
    WHEN EXISTS (SELECT 1 FROM ring2 WHERE auth_user_id IS NOT NULL)
      THEN EXISTS (SELECT 1 FROM ring2 JOIN me ON me.id = ring2.id)
    ELSE EXISTS (
      SELECT 1 FROM public.activity_log al
      WHERE al.table_name = 'family_members' AND al.row_id = p_target
        AND al.action = 'INSERT' AND al.actor_auth_user_id = auth.uid()
    )
  END;
$$;

GRANT EXECUTE ON FUNCTION public.is_claim_approver(UUID) TO authenticated;

DROP POLICY IF EXISTS "Approvers can read claim requests" ON public.merge_requests;
CREATE POLICY "Approvers can read claim requests"
  ON public.merge_requests
  FOR SELECT
  TO authenticated
  USING (
    kind = 'claim_request'
    AND requested_by_auth_user_id <> auth.uid()
    AND public.is_claim_approver(target_profile_id)
  );

-- approve/reject: identical to 017 except the gate is is_claim_approver.
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
  WHERE id = request_id AND kind = 'claim_request' AND status = 'pending'
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Claim request not found or already resolved';
  END IF;

  IF req.requested_by_auth_user_id = uid THEN
    RAISE EXCEPTION 'You cannot approve your own claim request';
  END IF;

  IF NOT public.is_claim_approver(req.target_profile_id) THEN
    RAISE EXCEPTION 'You are not allowed to approve this claim';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.family_members
    WHERE id = req.target_profile_id AND auth_user_id IS NULL
  ) THEN
    RAISE EXCEPTION 'Target profile is no longer claimable';
  END IF;

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
  WHERE id = request_id AND kind = 'claim_request' AND status = 'pending'
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Claim request not found or already resolved';
  END IF;

  IF req.requested_by_auth_user_id = uid THEN
    RAISE EXCEPTION 'You cannot reject your own claim request';
  END IF;

  IF NOT public.is_claim_approver(req.target_profile_id) THEN
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

-- ============================================================
-- Part 4 -- pending_claim_requests: approver-filtered + requester_email
-- ============================================================
-- Return type changes (new column), so DROP first; CREATE OR REPLACE can't.
-- The email is shown only to an eligible approver of that specific request,
-- so they can recognise (or not) the person asking. created_at = request time.
DROP FUNCTION IF EXISTS public.pending_claim_requests();
CREATE FUNCTION public.pending_claim_requests()
RETURNS TABLE (
  request_id UUID, created_at TIMESTAMPTZ, requester UUID, target JSONB,
  requester_email TEXT
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT mr.id, mr.created_at, mr.requested_by_auth_user_id, to_jsonb(fm.*),
         u.email::TEXT
  FROM public.merge_requests mr
  JOIN public.family_members fm ON fm.id = mr.target_profile_id
  LEFT JOIN auth.users u ON u.id = mr.requested_by_auth_user_id
  WHERE mr.kind = 'claim_request'
    AND mr.status = 'pending'
    AND mr.requested_by_auth_user_id <> auth.uid()
    AND public.is_claim_approver(mr.target_profile_id)
  ORDER BY mr.created_at DESC;
$$;

REVOKE ALL ON FUNCTION public.pending_claim_requests() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pending_claim_requests() TO authenticated;

COMMIT;
