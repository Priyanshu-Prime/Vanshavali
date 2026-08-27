-- 014: Connected-tree fetch — the whole family component reachable from a node.
--
-- Foundation for two features:
--   * The default tree view becoming a FULL tree (every relative connected to
--     you, not just the ego ±1 hop).
--   * Cross-tree isolation: you should only see people in your own connected
--     component; a separate, unconnected family tree stays invisible until a
--     shared node links the two.
--
-- get_connected_tree(root) walks the UNDIRECTED family graph from `root` —
-- parents, children, and spouses, transitively — and returns every reachable
-- family_members row exactly once. The recursive CTE's top-level UNION dedupes
-- visited ids, so cycles (and the naturally-shared nodes of a real tree)
-- terminate cleanly. SECURITY DEFINER so it can become the read boundary for
-- isolation later without each caller needing broad table SELECT.

BEGIN;

CREATE OR REPLACE FUNCTION public.get_connected_tree(root UUID)
RETURNS SETOF public.family_members
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH RECURSIVE component(id) AS (
    SELECT root
    UNION
    SELECT neighbor.id
    FROM component c
    JOIN LATERAL (
      -- parents of c
      SELECT me.father_id AS id FROM public.family_members me
        WHERE me.id = c.id AND me.father_id IS NOT NULL
      UNION ALL
      SELECT me.mother_id FROM public.family_members me
        WHERE me.id = c.id AND me.mother_id IS NOT NULL
      -- children of c
      UNION ALL
      SELECT ch.id FROM public.family_members ch
        WHERE ch.father_id = c.id OR ch.mother_id = c.id
      -- spouses of c (either direction)
      UNION ALL
      SELECT sr.spouse_id FROM public.spouse_relationships sr WHERE sr.member_id = c.id
      UNION ALL
      SELECT sr.member_id FROM public.spouse_relationships sr WHERE sr.spouse_id = c.id
    ) AS neighbor ON neighbor.id IS NOT NULL
  )
  SELECT fm.* FROM public.family_members fm
  WHERE fm.id IN (SELECT id FROM component);
$$;

GRANT EXECUTE ON FUNCTION public.get_connected_tree(UUID) TO authenticated;

COMMIT;
