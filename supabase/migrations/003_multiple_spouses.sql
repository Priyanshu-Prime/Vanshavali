-- Replace single spouse_id column with a many-to-many spouse relationship,
-- so a member can have more than one spouse over time (remarriage).

BEGIN;

-- ============================================
-- Table: spouse_relationships
-- ============================================
CREATE TABLE IF NOT EXISTS public.spouse_relationships (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,

  member_id UUID NOT NULL REFERENCES public.family_members(id) ON DELETE CASCADE,
  spouse_id UUID NOT NULL REFERENCES public.family_members(id) ON DELETE CASCADE,

  -- Canonical pair key so (A, B) and (B, A) are recognized as the same link
  -- regardless of insert order, without requiring the caller to sort ids.
  pair_key TEXT GENERATED ALWAYS AS (
    LEAST(member_id::TEXT, spouse_id::TEXT) || '_' || GREATEST(member_id::TEXT, spouse_id::TEXT)
  ) STORED,

  CONSTRAINT spouse_relationships_no_self CHECK (member_id <> spouse_id),
  CONSTRAINT spouse_relationships_unique_pair UNIQUE (pair_key)
);

CREATE INDEX IF NOT EXISTS idx_spouse_relationships_member_id ON public.spouse_relationships(member_id);
CREATE INDEX IF NOT EXISTS idx_spouse_relationships_spouse_id ON public.spouse_relationships(spouse_id);

-- ============================================
-- Row Level Security (RLS)
-- ============================================
ALTER TABLE public.spouse_relationships ENABLE ROW LEVEL SECURITY;

-- Policy 1: Everyone can read spousal links (public tree)
CREATE POLICY "Anyone can view spouse relationships"
  ON public.spouse_relationships
  FOR SELECT
  USING (true);

-- Policy 2: An authenticated user can create a link if they can edit either
-- side of it (their own claimed profile, or any unclaimed placeholder) —
-- mirrors the existing "update own row or unclaimed" permission model used
-- for family_members, since adding a spouse link is conceptually the same
-- kind of edit as setting father_id/mother_id used to be.
--
-- NOTE: member_id/spouse_id are explicitly qualified with the table name
-- below. family_members ALSO has a column named spouse_id (until the DROP
-- COLUMN further down), so an unqualified `spouse_id` inside the EXISTS
-- subquery's `family_members fm` scope resolves to fm.spouse_id instead of
-- the intended spouse_relationships row — silently creating a policy
-- dependency on family_members.spouse_id and breaking the later DROP
-- COLUMN. Always qualify correlated columns in a policy when the target
-- table's own column names can collide with a table referenced inside it.
CREATE POLICY "Editable-member users can add spouse relationships"
  ON public.spouse_relationships
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.family_members fm
      WHERE fm.id = spouse_relationships.member_id
        AND (fm.auth_user_id = auth.uid() OR fm.auth_user_id IS NULL)
    )
    OR EXISTS (
      SELECT 1 FROM public.family_members fm
      WHERE fm.id = spouse_relationships.spouse_id
        AND (fm.auth_user_id = auth.uid() OR fm.auth_user_id IS NULL)
    )
  );

-- Policy 3: Same permission model applies to removing a link (correcting a
-- mistake), not the stricter "unclaimed only" delete rule on family_members
-- itself — this deletes a relationship row, not a person. Same qualification
-- note as Policy 2 applies here.
CREATE POLICY "Editable-member users can remove spouse relationships"
  ON public.spouse_relationships
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.family_members fm
      WHERE fm.id = spouse_relationships.member_id
        AND (fm.auth_user_id = auth.uid() OR fm.auth_user_id IS NULL)
    )
    OR EXISTS (
      SELECT 1 FROM public.family_members fm
      WHERE fm.id = spouse_relationships.spouse_id
        AND (fm.auth_user_id = auth.uid() OR fm.auth_user_id IS NULL)
    )
  );

GRANT ALL ON public.spouse_relationships TO anon, authenticated;

-- ============================================
-- Migrate existing spouse_id data into the new table
-- ============================================
INSERT INTO public.spouse_relationships (member_id, spouse_id)
SELECT id, spouse_id FROM public.family_members
WHERE spouse_id IS NOT NULL
ON CONFLICT (pair_key) DO NOTHING;

-- ============================================
-- Drop the old single-spouse column
-- ============================================
DROP INDEX IF EXISTS idx_family_members_spouse_id;
ALTER TABLE public.family_members DROP COLUMN IF EXISTS spouse_id;

-- ============================================
-- RPC Function: Get Ego-Centric Network (updated for multi-spouse)
-- ============================================
CREATE OR REPLACE FUNCTION get_ego_network(center_member_id UUID)
RETURNS SETOF public.family_members
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH center AS (
    SELECT * FROM public.family_members WHERE id = center_member_id
  ),
  related_ids AS (
    -- The center member
    SELECT id FROM center
    UNION
    -- Father
    SELECT father_id FROM center WHERE father_id IS NOT NULL
    UNION
    -- Mother
    SELECT mother_id FROM center WHERE mother_id IS NOT NULL
    UNION
    -- Spouses (any number, current or from a prior marriage)
    SELECT CASE WHEN sr.member_id = center_member_id THEN sr.spouse_id ELSE sr.member_id END
    FROM public.spouse_relationships sr
    WHERE sr.member_id = center_member_id OR sr.spouse_id = center_member_id
    UNION
    -- Children (where center is father or mother)
    SELECT fm.id FROM public.family_members fm
    WHERE fm.father_id = center_member_id OR fm.mother_id = center_member_id
    UNION
    -- Siblings (share same father or mother)
    SELECT fm.id FROM public.family_members fm, center c
    WHERE (fm.father_id = c.father_id AND c.father_id IS NOT NULL)
       OR (fm.mother_id = c.mother_id AND c.mother_id IS NOT NULL)
  )
  SELECT fm.* FROM public.family_members fm
  WHERE fm.id IN (SELECT id FROM related_ids);
END;
$$;

GRANT EXECUTE ON FUNCTION get_ego_network(UUID) TO anon, authenticated;

-- Note: spouse_relationships rows for a set of members are read directly via
-- the public SELECT policy above (client filters with .or(...)), matching
-- the existing style used for getChildren/getSiblings — no RPC needed since
-- there's no privileged logic involved, just a public read.

COMMIT;
