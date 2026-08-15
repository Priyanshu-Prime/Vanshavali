---
name: family-relations
description: Use when touching family-relationship logic in Vanshavali — adding/editing father, mother, spouse, child, or sibling links, the add-family-member flow, or the ego-network fetch. These rules are easy to get subtly wrong and have caused duplicate-relation and stale-data bugs before.
---

# Family relationship rules

## Relation cardinality — this is the rule most likely to be violated

- **Father and mother are one-to-one.** A member can have at most one of each. Any
  UI or save path that sets one of these must first check whether it's already set
  and block/replace explicitly — never silently allow a second one.
- **Spouse is multi-entry (supports remarriage).** Spouses are stored as edges in
  `public.spouse_relationships`, not a single `spouse_id` column (that column was
  removed in migration `003_multiple_spouses.sql`). A member can have more than one
  spouse over time. The guard here is not "block a second spouse" — it's "don't
  insert the exact same pair twice." Re-fetch current spouse links before inserting
  to avoid a stale-data duplicate (same principle as below, applied to a set-
  membership check instead of a single-value check).
- **Child and sibling are multi-entry.** Do not apply a one-to-one guard to these;
  siblings in particular are typically *derived* from shared parents rather than
  stored as a direct edge — check `family_provider.dart` for how siblings are
  computed before assuming they're a stored field.

## Stale-data guard (previously a real bug source)

Relationship state is touched from both local cache (`local_storage_service.dart`)
and Supabase. Before writing a one-to-one relation, **re-fetch the latest member
record from Supabase first**, then check the guard against that fresh data — not
against whatever is currently held in local/provider state. A stale in-memory copy
has previously allowed duplicate father/mother/spouse relations to slip through.

## Spouse-add side effect

When a spouse is linked to a member who already has children, the flow must prompt
the user to link those existing children to the new spouse — but only offer this
for children whose *other-parent slot is currently empty*. Never overwrite an
already-assigned father_id/mother_id just because a new spouse (e.g. after
remarriage) was added; that would silently rewrite a child's biological parent.
This is intentional product behavior (not an edge case to suppress) — see
`docs/claude_handoff/01_requirements_and_goals.md`. If you're removing or
refactoring the spouse-add path, preserve this prompt and its empty-slot condition.

## Ego-centric fetching

Never fetch the whole village. All tree/relation views must go through (or preserve
the intent of) `get_ego_network(center_member_id)`: center member + parents +
children + spouse only. Tapping a node re-centers the fetch on that node rather than
expanding the already-loaded set.

## Ancestry-cycle guard (father/mother "link existing")

Setting `target.fatherId`/`target.motherId` to an EXISTING member's id (via "Add
Father/Mother" → "Link Existing") must never create a cycle — i.e. the candidate
must not already be a descendant of the target. This is guarded client-side by
`wouldCreateAncestryCycle` in `add_family_member_screen.dart`, called from
`_saveMember` right alongside the one-to-one cardinality guard. There is still no
database-level constraint against this (nothing in the schema/RLS stops it) — the
app-level guard at this one entry point is currently the only thing preventing it,
so don't remove/bypass this check when touching the father/mother "link existing"
flow. The tree-*rendering* side (`buildPedigreeChain` in `family_tree_screen.dart`)
also has its own independent cycle guard, but that only stops the UI from hanging
on bad data that already exists — it does not prevent bad data from being created.

## Placeholder ("ghost") profiles

A `family_members` row with `auth_user_id IS NULL` is a placeholder created by a
relative, not a bug. Relationship logic must work identically for placeholder and
claimed profiles — don't assume `auth_user_id` is non-null when writing relation
code. See `supabase-migration` skill for the claim-flow constraints on these rows.
