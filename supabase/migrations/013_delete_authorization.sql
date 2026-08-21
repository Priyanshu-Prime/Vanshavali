-- 013: Align DELETE authorization with the edit rule.
--
-- The original DELETE policy (migration 001) was USING (auth_user_id IS NULL):
-- any unclaimed node was deletable, but a CLAIMED node could never be deleted —
-- not even by its own owner. That leaves no way to remove your own profile, and
-- it's inconsistent with can_edit_family_member (the single source of truth for
-- "who may modify this row", relaxed in 012 to own-claimed-or-any-unclaimed).
--
-- Rule after this migration (matches edit):
--   * Any UNCLAIMED node:            deletable by any member (clean up bad data).
--   * Your OWN claimed node:         deletable by you.
--   * Someone else's CLAIMED node:   never deletable — a real registered user's
--                                    node is safe from anyone but themselves.
--
-- Foreign keys already make the cascade safe: father_id/mother_id/spouse_id are
-- ON DELETE SET NULL (children keep existing, just lose the link) and
-- spouse_relationships / member_private_details are ON DELETE CASCADE.

BEGIN;

DROP POLICY IF EXISTS "Users can delete unclaimed profiles" ON public.family_members;

CREATE POLICY "Delete self or unclaimed nodes"
  ON public.family_members
  FOR DELETE
  TO authenticated
  USING (public.can_edit_family_member(id));

COMMIT;
