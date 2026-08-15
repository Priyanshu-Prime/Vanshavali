-- Pedigree view was showing only the focus member's parents, never
-- grandparents/great-grandparents. Root cause: FamilyTreeScreen's
-- buildPedigreeChain() resolves each ancestor id against
-- FamilyProvider.egoNetwork, but get_ego_network() (see
-- 003_multiple_spouses.sql) only ever returns the center member + parents +
-- spouses + children + siblings — ONE generation up, by design, since that's
-- the right scope for the default ego-centric tree view. A pedigree chart
-- needs several generations of ancestors, which get_ego_network was never
-- meant to provide.
--
-- Fix: a dedicated RPC that recursively walks BOTH father_id and mother_id
-- up to max_generations (default 6 — comfortably past "great-grandfather",
-- 3 generations, with headroom) and returns every ancestor found, so the
-- client can resolve a full paternal or maternal pedigree line locally
-- without extra round trips per generation (this app's target rural network
-- conditions make round-trip count matter). Returns both branches at every
-- step (not just the one line currently selected in the UI) so switching
-- between the Paternal/Maternal toggle doesn't need a re-fetch.
--
-- Bounded and cycle-safe the same way the app-level wouldCreateAncestryCycle
-- guard is (add_family_member_screen.dart): a visited-ids array stops a
-- pre-existing bad-data cycle from making the recursion loop forever, and
-- max_generations caps the worst case regardless.

BEGIN;

CREATE OR REPLACE FUNCTION get_ancestor_chain(
  center_member_id UUID,
  max_generations INT DEFAULT 6
)
RETURNS SETOF public.family_members
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH RECURSIVE ancestors AS (
    SELECT fm.id, 0 AS generation, ARRAY[fm.id] AS visited
    FROM public.family_members fm
    WHERE fm.id = center_member_id
    UNION ALL
    SELECT parent.id, a.generation + 1, a.visited || parent.id
    FROM ancestors a
    JOIN public.family_members child ON child.id = a.id
    JOIN public.family_members parent
      ON parent.id = child.father_id OR parent.id = child.mother_id
    WHERE a.generation < max_generations
      AND NOT parent.id = ANY(a.visited)
  )
  SELECT fm.*
  FROM public.family_members fm
  WHERE fm.id IN (SELECT DISTINCT id FROM ancestors);
END;
$$;

GRANT EXECUTE ON FUNCTION get_ancestor_chain(UUID, INT) TO anon, authenticated;

COMMIT;
