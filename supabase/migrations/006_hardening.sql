-- Hardening pass from the 2026-08-16 architecture review (see
-- docs/claude_handoff and the Claude memory file
-- vanshavali_architecture_review_2026-08-16.md). Closes four real gaps:
--
-- 1. Nothing at the DB level stopped a second family_members row for one
--    auth_user_id — the app-level fix for the duplicate-profile incident
--    was defense-in-depth on top of an open door, not a closed door.
-- 2. The whole tree was readable by anyone with the (public, APK-embedded)
--    anon key, no login required.
-- 3. No updated_at column, so incremental sync (filtering on created_at,
--    which never changes) silently misses edits made on other devices.
-- 4. No DB-level guard against a father_id/mother_id cycle — only the
--    app-level wouldCreateAncestryCycle guard at one entry point
--    (add_family_member_screen.dart) existed; a cycle could still be
--    created via direct API/SQL access.
--
-- IMPORTANT — apply-order gate: this migration WILL FAIL to create the
-- unique index below while a duplicate auth_user_id exists. Before running
-- this file, confirm zero duplicates:
--   SELECT auth_user_id, count(*) FROM public.family_members
--   WHERE auth_user_id IS NOT NULL GROUP BY auth_user_id HAVING count(*) > 1;
-- If that returns any rows, resolve them first (merge/delete the extra row).

BEGIN;

-- ============================================
-- 1. Prevent duplicate profiles at the DB level
-- ============================================
DROP INDEX IF EXISTS idx_family_members_auth_user_id;
CREATE UNIQUE INDEX idx_family_members_auth_user_id_unique
  ON public.family_members(auth_user_id)
  WHERE auth_user_id IS NOT NULL;

DROP POLICY IF EXISTS "Authenticated users can insert family members" ON public.family_members;
CREATE POLICY "Authenticated users can insert family members"
  ON public.family_members
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth_user_id IS NULL OR auth_user_id = auth.uid()
  );

-- ============================================
-- 2. Reads require login (was: USING (true), readable by anon)
-- ============================================
DROP POLICY IF EXISTS "Anyone can view family members" ON public.family_members;
CREATE POLICY "Authenticated users can view family members"
  ON public.family_members
  FOR SELECT
  TO authenticated
  USING (true);

-- Defense in depth: migration 001 granted ALL to anon; RLS already blocks
-- reads with no matching policy, but anon shouldn't hold table privileges
-- it has no legitimate use for. Invite preview/claim keep working — they
-- run through SECURITY DEFINER RPCs (get_member_by_invite_code,
-- claim_profile, claim_profile_by_code), which bypass both RLS and grants.
REVOKE ALL ON public.family_members FROM anon;

-- ============================================
-- 3. updated_at, so incremental sync can actually detect edits
-- ============================================
ALTER TABLE public.family_members
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_family_members_updated_at ON public.family_members;
CREATE TRIGGER trg_family_members_updated_at
  BEFORE UPDATE ON public.family_members
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- ============================================
-- 4. DB-level ancestry-cycle guard (backstop for the app-level guard)
-- ============================================
-- Same recursive-CTE shape as get_ancestor_chain (migration 005): walks
-- the candidate parent's full ancestor tree (both father_id and mother_id
-- branches) and rejects the write if the row being saved would appear in
-- its own ancestor chain. Checked independently for father_id and
-- mother_id since either alone could create a cycle.
CREATE OR REPLACE FUNCTION public.prevent_ancestry_cycle()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.father_id IS NOT NULL AND EXISTS (
    WITH RECURSIVE ancestors AS (
      SELECT id, father_id, mother_id, ARRAY[id] AS visited
      FROM public.family_members WHERE id = NEW.father_id
      UNION ALL
      SELECT fm.id, fm.father_id, fm.mother_id, a.visited || fm.id
      FROM ancestors a
      JOIN public.family_members fm ON fm.id = a.father_id OR fm.id = a.mother_id
      WHERE NOT fm.id = ANY(a.visited) AND array_length(a.visited, 1) < 100
    )
    SELECT 1 FROM ancestors WHERE id = NEW.id
  ) THEN
    RAISE EXCEPTION 'Ancestry cycle detected: member cannot be their own ancestor via father_id';
  END IF;

  IF NEW.mother_id IS NOT NULL AND EXISTS (
    WITH RECURSIVE ancestors AS (
      SELECT id, father_id, mother_id, ARRAY[id] AS visited
      FROM public.family_members WHERE id = NEW.mother_id
      UNION ALL
      SELECT fm.id, fm.father_id, fm.mother_id, a.visited || fm.id
      FROM ancestors a
      JOIN public.family_members fm ON fm.id = a.father_id OR fm.id = a.mother_id
      WHERE NOT fm.id = ANY(a.visited) AND array_length(a.visited, 1) < 100
    )
    SELECT 1 FROM ancestors WHERE id = NEW.id
  ) THEN
    RAISE EXCEPTION 'Ancestry cycle detected: member cannot be their own ancestor via mother_id';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_ancestry_cycle ON public.family_members;
CREATE TRIGGER trg_prevent_ancestry_cycle
  BEFORE INSERT OR UPDATE OF father_id, mother_id ON public.family_members
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_ancestry_cycle();

COMMIT;
