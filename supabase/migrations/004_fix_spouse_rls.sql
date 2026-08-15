-- Tighten spouse_relationships RLS. The INSERT/DELETE policies added in
-- 003_multiple_spouses.sql use OR across both sides of the pair:
--
--   EXISTS (... fm.id = member_id AND (fm.auth_user_id = auth.uid() OR fm.auth_user_id IS NULL))
--   OR EXISTS (... fm.id = spouse_id AND (fm.auth_user_id = auth.uid() OR fm.auth_user_id IS NULL))
--
-- This lets an authenticated user link or unlink a spousal record between
-- TWO PEOPLE THEY HAVE NO CONNECTION TO, as long as either side happens to
-- be an unclaimed placeholder — which is common in this app. E.g.:
-- member_id = someone else's claimed profile, spouse_id = any unclaimed
-- placeholder anywhere in the village. The second EXISTS alone satisfies
-- the check; nothing validates the caller has any relationship to the
-- claimed side at all.
--
-- Fix: require either (a) the caller owns one side of the pair via their
-- own claimed profile (asserting a relationship involving themselves —
-- allowed against any other member, claimed or not, matching how
-- father_id/mother_id assignment elsewhere in this app never requires the
-- REFERENCED parent to be unclaimed or owned by the caller), or (b) BOTH
-- sides are unclaimed placeholders (managing two relatives' records with no
-- real, non-consenting person involved — e.g. linking two deceased
-- ancestors who never had accounts). A claimed profile belonging to someone
-- other than the caller can now never be touched unless the caller owns
-- the other side.

BEGIN;

DROP POLICY IF EXISTS "Editable-member users can add spouse relationships" ON public.spouse_relationships;
DROP POLICY IF EXISTS "Editable-member users can remove spouse relationships" ON public.spouse_relationships;

CREATE POLICY "Editable-member users can add spouse relationships"
  ON public.spouse_relationships
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.family_members fm
      WHERE fm.id = spouse_relationships.member_id AND fm.auth_user_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM public.family_members fm
      WHERE fm.id = spouse_relationships.spouse_id AND fm.auth_user_id = auth.uid()
    )
    OR (
      EXISTS (
        SELECT 1 FROM public.family_members fm
        WHERE fm.id = spouse_relationships.member_id AND fm.auth_user_id IS NULL
      )
      AND EXISTS (
        SELECT 1 FROM public.family_members fm
        WHERE fm.id = spouse_relationships.spouse_id AND fm.auth_user_id IS NULL
      )
    )
  );

CREATE POLICY "Editable-member users can remove spouse relationships"
  ON public.spouse_relationships
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.family_members fm
      WHERE fm.id = spouse_relationships.member_id AND fm.auth_user_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM public.family_members fm
      WHERE fm.id = spouse_relationships.spouse_id AND fm.auth_user_id = auth.uid()
    )
    OR (
      EXISTS (
        SELECT 1 FROM public.family_members fm
        WHERE fm.id = spouse_relationships.member_id AND fm.auth_user_id IS NULL
      )
      AND EXISTS (
        SELECT 1 FROM public.family_members fm
        WHERE fm.id = spouse_relationships.spouse_id AND fm.auth_user_id IS NULL
      )
    )
  );

COMMIT;
