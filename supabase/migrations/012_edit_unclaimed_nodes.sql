-- 012: Let tree-building actually work — allow editing/linking ANY unclaimed
-- node, not just your direct ±1 relatives.
--
-- Migration 010 restricted edits to "your own profile + your father/mother/
-- child/spouse/sibling". That looked safe, but it breaks this app's core
-- feature: building out a multi-generation tree means adding ancestors and
-- relatives to placeholder nodes that are, by definition, NOT your direct ±1
-- relatives — your grandfather's father, a cousin's child, a great-aunt.
--
-- Real report that surfaced it: a user could not add his grandfather's father.
-- The new placeholder was created (INSERT ok) but the UPDATE linking the
-- grandfather to it was silently filtered by RLS (grandfather is 2 hops away,
-- so can_edit_family_member returned FALSE), leaving a string of disconnected
-- orphan placeholders and a node that never appeared in the tree.
--
-- The protection that actually matters — and the one that was originally
-- reported (you must not be able to edit someone else's CLAIMED profile) — is
-- kept intact. The "direct relatives only" restriction on UNCLAIMED nodes is
-- dropped: in a single trusted ~500-person village tree everything is
-- interconnected, and unclaimed placeholders are inherently communal data that
-- any participating member may complete. A member must still have their own
-- profile to edit anything (so a freshly-signed-up account with no profile
-- can't touch the tree), and claiming-by-edit stays blocked by the unique
-- auth_user_id index (migration 006) plus WITH CHECK.
--
-- Model after this migration:
--   * Your own profile (auth_user_id = you):            editable.
--   * Any UNCLAIMED node (auth_user_id IS NULL):        editable by any member.
--   * Someone else's CLAIMED node:                      never editable.
--
-- This also makes the set_member_parents RPC (011) and the direct-UPDATE paths
-- agree: both now allow own-or-unclaimed, so father/mother/child/sibling links
-- to distant placeholders all persist. No app rebuild is required — the
-- already-shipped client's direct UPDATE simply stops being filtered.

BEGIN;

CREATE OR REPLACE FUNCTION public.can_edit_family_member(target_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
  uid    UUID := auth.uid();
  target public.family_members;
BEGIN
  IF uid IS NULL THEN
    RETURN FALSE;
  END IF;

  SELECT * INTO target FROM public.family_members WHERE id = target_id;
  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;

  -- Your own profile: always editable.
  IF target.auth_user_id = uid THEN
    RETURN TRUE;
  END IF;

  -- Any other CLAIMED profile: never editable (the real protection — a creator
  -- can no longer edit a relative's node once that relative claims it).
  IF target.auth_user_id IS NOT NULL THEN
    RETURN FALSE;
  END IF;

  -- Target is UNCLAIMED. Editable by any member who has a profile of their own
  -- (so the tree stays communally completable), regardless of hop distance.
  RETURN EXISTS (SELECT 1 FROM public.family_members WHERE auth_user_id = uid);
END;
$$;

COMMIT;
