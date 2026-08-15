---
name: supabase-migration
description: Use when adding or changing a Supabase SQL migration under supabase/migrations/, adding an RPC, changing RLS policies, or changing any column on public.family_members. Keeps the SQL schema, RLS, and the Dart model in sync for this zero-cost Supabase-backed Flutter app.
---

# Supabase schema changes for Vanshavali

## Conventions already established

- Migrations live in `supabase/migrations/`, numbered sequentially:
  `001_initial_schema.sql`, `002_invite_code.sql`. Add the next file as
  `00N_short_description.sql` — never edit an already-applied migration in place.
- Core table is `public.family_members`, self-referencing via `father_id` and
  `mother_id` (both one-to-one). Spouse is a many-to-many self-relation stored in
  `public.spouse_relationships` (added in `003_multiple_spouses.sql`, replacing the
  original single `spouse_id` column) so a member can have multiple spouses over
  time (remarriage). Child/sibling relations are derived from `father_id`/
  `mother_id`, not stored directly.
- `auth_user_id` NULL means a placeholder/"ghost" profile created by a relative;
  non-NULL means a claimed, real user.
- Existing RPCs: `claim_profile(profile_id UUID)`,
  `get_ego_network(center_member_id UUID)`,
  `search_family_members(search_query TEXT, result_limit INT)`. Prefer adding a new
  RPC over pushing multi-step relational logic into the Flutter client — the app
  relies on RPCs to keep claim/link operations atomic.

## Hard constraints (do not break these)

- **Zero-cost**: stay within Supabase free-tier features. No paid extensions, no
  features that require a paid plan.
- **RLS must remain**: public read on `family_members` (it's a public tree), but
  writes restricted to `auth_user_id = auth.uid()` for the owner's own row. Don't
  weaken this to "unblock" a feature — fix the RPC/policy properly instead.
- **Claiming must stay idempotent-safe**: `claim_profile` must only succeed for
  currently-unclaimed rows (`auth_user_id IS NULL`), or you risk hijacking someone
  else's profile.
- **Ego-centric fetching**: `get_ego_network` (or any replacement) must keep
  returning only the centered member + parents + children + spouse — never the
  whole table. The Flutter side depends on this to stay affordable and fast at
  village scale.

## After writing the migration

1. Update `lib/models/family_member.dart` to match any column changes.
2. If the model has a Hive/local-cache representation (`local_storage_service.dart`),
   update it too — **never reuse a Hive field number**, only add new ones.
3. Update `docs/claude_handoff/06_supabase_and_data_model.md` if the schema or RPC
   surface changed, so the handoff doc doesn't drift from reality.
4. Run through the `verify` skill's relationship-guard and invite/claim checks if the
   change touches `family_members` columns or the claim RPC.
