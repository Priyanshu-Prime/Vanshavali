-- 010: Restrict who may EDIT a family member, and add a full activity log.
--
-- BEFORE this migration the UPDATE policy (migration 001) was
--   USING (auth_user_id = auth.uid() OR auth_user_id IS NULL)
-- which let ANY authenticated user edit ANY unclaimed node anywhere in the
-- village, with no relationship restriction at all. This tightens it to the
-- intended rule and records every write for audit/debugging.

BEGIN;

-- ============================================================
-- Part 1 — Edit authorization
-- ============================================================
-- Rule:
--   * You may always edit your OWN profile (auth_user_id = auth.uid()).
--   * You may edit an UNCLAIMED node (auth_user_id IS NULL) only if it is a
--     direct ±1 relative of your own profile: your father, mother, child,
--     spouse, or sibling (either parent's side).
--   * A CLAIMED profile belonging to someone else is NEVER editable by anyone
--     other than that person.
--
-- SECURITY DEFINER so the policy can read family_members / spouse_relationships
-- without tripping RLS recursion; the internal reads run as the table owner.
CREATE OR REPLACE FUNCTION public.can_edit_family_member(target_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
  uid UUID := auth.uid();
  target public.family_members;
  me public.family_members;
BEGIN
  IF uid IS NULL THEN
    RETURN FALSE;
  END IF;

  SELECT * INTO target FROM public.family_members WHERE id = target_id;
  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;

  -- Own profile: always editable.
  IF target.auth_user_id = uid THEN
    RETURN TRUE;
  END IF;

  -- Any other claimed profile: never editable.
  IF target.auth_user_id IS NOT NULL THEN
    RETURN FALSE;
  END IF;

  -- Target is unclaimed — load the caller's own profile to check kinship.
  SELECT * INTO me FROM public.family_members WHERE auth_user_id = uid;
  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;

  -- Parent of me.
  IF target.id = me.father_id OR target.id = me.mother_id THEN
    RETURN TRUE;
  END IF;

  -- Child of me.
  IF me.id = target.father_id OR me.id = target.mother_id THEN
    RETURN TRUE;
  END IF;

  -- Sibling of me (shares a parent on either side).
  IF (me.father_id IS NOT NULL AND target.father_id = me.father_id)
     OR (me.mother_id IS NOT NULL AND target.mother_id = me.mother_id) THEN
    RETURN TRUE;
  END IF;

  -- Spouse of me.
  IF EXISTS (
    SELECT 1 FROM public.spouse_relationships sr
    WHERE (sr.member_id = me.id AND sr.spouse_id = target.id)
       OR (sr.member_id = target.id AND sr.spouse_id = me.id)
  ) THEN
    RETURN TRUE;
  END IF;

  RETURN FALSE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.can_edit_family_member(UUID) TO authenticated;

-- Swap the permissive policy for the kinship-aware one.
DROP POLICY IF EXISTS "Users can update their own profile" ON public.family_members;

CREATE POLICY "Edit self or direct unclaimed relatives"
  ON public.family_members
  FOR UPDATE
  TO authenticated
  USING (public.can_edit_family_member(id))
  WITH CHECK (public.can_edit_family_member(id));
-- Note: setting auth_user_id to your own id on a relative's node ("claim by
-- edit") is already blocked by the unique index on auth_user_id (migration
-- 006) — a user with a profile can't create a second row bearing their id —
-- and by WITH CHECK, which re-evaluates on the NEW row (a foreign auth link
-- fails every branch). Claiming stays exclusively on the claim_profile RPCs.

-- ============================================================
-- Part 2 — Activity log (audit trail for every write)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.activity_log (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  -- Who did it (the real end user, even inside a SECURITY DEFINER RPC —
  -- auth.uid() reads the JWT, not the executing DB role). NULL only for
  -- system/service actions.
  actor_auth_user_id UUID,
  action TEXT NOT NULL,          -- INSERT | UPDATE | DELETE
  table_name TEXT NOT NULL,
  row_id UUID,
  old_data JSONB,
  new_data JSONB
);

CREATE INDEX IF NOT EXISTS idx_activity_log_created_at
  ON public.activity_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_log_actor
  ON public.activity_log(actor_auth_user_id);
CREATE INDEX IF NOT EXISTS idx_activity_log_row
  ON public.activity_log(table_name, row_id);

-- Locked down: no client may read or write this table directly. Rows are
-- written only by the SECURITY DEFINER trigger below (running as owner, which
-- bypasses RLS); reads are for the project owner via the service role /
-- dashboard only.
ALTER TABLE public.activity_log ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.activity_log FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.log_activity()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.activity_log(
    actor_auth_user_id, action, table_name, row_id, old_data, new_data
  )
  VALUES (
    auth.uid(),
    TG_OP,
    TG_TABLE_NAME,
    COALESCE(NEW.id, OLD.id),
    CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) ELSE NULL END,
    CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW) ELSE NULL END
  );
  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_log_family_members ON public.family_members;
CREATE TRIGGER trg_log_family_members
  AFTER INSERT OR UPDATE OR DELETE ON public.family_members
  FOR EACH ROW EXECUTE FUNCTION public.log_activity();

DROP TRIGGER IF EXISTS trg_log_spouse_relationships ON public.spouse_relationships;
CREATE TRIGGER trg_log_spouse_relationships
  AFTER INSERT OR UPDATE OR DELETE ON public.spouse_relationships
  FOR EACH ROW EXECUTE FUNCTION public.log_activity();

COMMIT;
