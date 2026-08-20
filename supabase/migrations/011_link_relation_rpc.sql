-- 011: Fix the add-sibling / link-existing-child regression introduced by 010.
--
-- Migration 010's UPDATE policy authorizes a write by reading the target row's
-- CURRENT (committed) relationships via can_edit_family_member(). That works for
-- editing an EXISTING relative, but it silently blocks the write that CREATES a
-- relationship in the first place:
--
--   * Adding a sibling  -> UPDATE sibling SET father_id/mother_id = my parents
--   * Linking an existing person as a child
--   * Adding a child when the parent's gender is 'Other'
--
-- In each case the kinship edge does not exist yet at the moment of the UPDATE,
-- so can_edit_family_member() returns FALSE, RLS filters the row out, and the
-- UPDATE affects 0 rows with NO error — the app reports success but nothing
-- links. (Father/mother work because they update your OWN row; new children of
-- a Male/Female parent work because the link is baked into the INSERT.)
--
-- Fix: a narrow SECURITY DEFINER RPC that performs ONLY the parent-pointer write
-- for the child/sibling flows, with its own authorization check. It preserves
-- the protections 010 added:
--   * You must be authenticated and have your own profile.
--   * You may set parents only on YOUR OWN row or an UNCLAIMED node — never on
--     a claimed profile that belongs to someone else (the real hole 010 closed).
-- Content edits (renames, detail changes) still go through the strict RLS
-- UPDATE policy via the direct table write in updateFamilyMember — this RPC does
-- not widen those. The updated_at, ancestry-cycle, and activity-log triggers all
-- still fire inside the function (it runs as owner but the triggers are
-- unconditional), so the DB-level cycle backstop and audit trail are intact.

BEGIN;

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

  -- Caller must have a profile of their own (mirrors can_edit_family_member).
  IF NOT EXISTS (SELECT 1 FROM public.family_members WHERE auth_user_id = uid) THEN
    RAISE EXCEPTION 'Caller has no profile';
  END IF;

  SELECT * INTO child FROM public.family_members WHERE id = p_child;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Target member not found';
  END IF;

  -- May set parents only on your own row or an unclaimed placeholder. A claimed
  -- profile belonging to someone else is never re-parentable by anyone else —
  -- this is the same rule can_edit_family_member enforces, kept intact here.
  IF child.auth_user_id IS NOT NULL AND child.auth_user_id <> uid THEN
    RAISE EXCEPTION 'Cannot modify a claimed profile you do not own';
  END IF;

  -- COALESCE so a NULL argument leaves that parent slot unchanged (the caller
  -- sets only the slot(s) it means to: one for a child, one-or-both for a
  -- sibling). Clearing a parent is intentionally not supported here.
  UPDATE public.family_members
     SET father_id = COALESCE(p_father, father_id),
         mother_id = COALESCE(p_mother, mother_id)
   WHERE id = p_child;
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_member_parents(UUID, UUID, UUID) TO authenticated;

COMMIT;
