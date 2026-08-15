# Supabase and Data Model Notes

## CRITICAL — unapplied migration
**`004_fix_spouse_rls.sql` exists on disk but has NOT been run against the
live Supabase project.** Migrations 001-003 have been applied (confirmed
indirectly via live Android device testing of the tree screen, which reads
`spouse_relationships` through `get_ego_network` and hit no schema/RPC
errors). Until 004 is applied via the Supabase SQL editor, the live
`spouse_relationships` INSERT/DELETE policies are still the looser ones from
003 — see the RLS gap described below and `04_current_risks.md`.

## Current Supabase config
- Project URL is stored in `lib/config/app_config.dart`.
- Magic-link redirect uses the custom scheme `vanshavali://auth/callback`.

## Base schema
`public.family_members` (after 001+002+003, applied live) has:
- `id`
- `created_at`
- `auth_user_id`
- `father_id`
- `mother_id`
- bilingual name fields
- `gender`
- `dob`
- `is_alive`
- `village_origin`
- `current_city`
- `deep_details`
- invite-code columns added by `002_invite_code.sql`

`spouse_id` was **dropped** by `003_multiple_spouses.sql` and no longer
exists on this table (003 is applied live).

There is no database-level constraint preventing a `father_id`/`mother_id`
ancestry cycle (e.g. two members set as each other's ancestor via bad data
entry) — nothing in this schema or in RLS checks for that. An app-level
guard (`wouldCreateAncestryCycle` in `add_family_member_screen.dart`) now
blocks this at the one app entry point that could create one, but that is
enforced in Dart, not by the database — direct API/SQL access bypassing the
app is still unconstrained. See `04_current_risks.md`.

## `spouse_relationships` table (added by 003, live)
Many-to-many join table replacing the old one-to-one `spouse_id` column, so a
member can have more than one spouse over time (remarriage):
- `id`, `created_at`
- `member_id UUID REFERENCES family_members(id) ON DELETE CASCADE`
- `spouse_id UUID REFERENCES family_members(id) ON DELETE CASCADE`
- `pair_key` — generated column (`LEAST(member_id, spouse_id) || '_' || GREATEST(...)`),
  `UNIQUE`, so (A,B) and (B,A) inserts collide regardless of order — this is
  what prevents duplicate spouse pairs, not application logic
- `CHECK (member_id <> spouse_id)`
- RLS: public SELECT. INSERT/DELETE **as currently live** (003's version)
  allow either side of the pair to independently satisfy the check — this is
  a **known RLS gap**: it lets an authenticated user link/unlink a spousal
  record between two people they have no connection to, as long as either
  side happens to be an unclaimed placeholder (common in this app).
  `004_fix_spouse_rls.sql` (written, **not yet applied**) tightens this to:
  the caller must own one side via their own claimed profile, OR both sides
  must be unclaimed placeholders. See the migration file for full reasoning
  and `04_current_risks.md`.
- No RPC for reading spouse links — client reads directly via the public
  SELECT policy with `.or(...)`, matching the existing style for
  getChildren/getSiblings

`FamilyMember.spouseId` is fully removed from the Dart model
(`lib/models/family_member.dart`); Hive field index 5 (previously `spouseId`)
is retired and must never be reused. A new `SpouseLink` class was added to
the same file to represent a row of `spouse_relationships` on the client.

## RPCs already in use
- `claim_profile(profile_id UUID)`
- `get_ego_network(center_member_id UUID)` — updated by 003 to traverse
  `spouse_relationships` instead of the old `spouse_id` column. Still returns
  only father, mother, spouse(s), children, and siblings of the center
  member — never grandparents or deeper ancestors, per the project's
  mandatory ego-centric-fetch requirement (CLAUDE.md §4B). This caps Pedigree
  View at ~1 ancestor generation beyond the focus member; whether that's
  intentional or needs a dedicated ancestor-chain RPC is an open product
  question — see `02_work_completed.md` and `05_next_steps.md`.
- `search_family_members(search_query TEXT, result_limit INT)`

## Invite-code migration
The second migration adds invite-code support and claim-by-code behavior.

## App-managed flag in `deep_details` — `has_password`
`deep_details['has_password']` (boolean) tracks whether the profile's auth
account has ever had a password set. This is **not a schema column and
required no migration** — Supabase's client SDK doesn't expose "does this
identity have a password" directly, so the app tracks it itself in the
existing flexible `deep_details` jsonb column. Set by
`AuthProvider.setPassword`/self-healed by `signInWithEmail`
(`lib/providers/auth_provider.dart`), read by `AuthProvider.hasPasswordSet`,
which drives a mandatory (non-skippable) `SetPasswordScreen` for any account
missing it — see `04_current_risks.md` for the behavior-change implications
for existing accounts, and `02_work_completed.md` for full detail. Chosen
over a dedicated `family_members` column since this is arguably auth-state,
not profile data — worth reconsidering if more auth-state flags accumulate.

## Auth signUp anti-enumeration behavior — real incident, see `04_current_risks.md`
Supabase's `client.auth.signUp()` does not cleanly error when the email
already has an account — it silently attaches the new password to the
existing `auth.users` row and returns a normal-looking success. An empty
`response.user!.identities` list is Supabase's documented signal that this
happened. `SupabaseService.signUpWithEmail` now checks for this and throws
`AuthException('vanshavali_email_already_registered')`. Before this fix, the
app treated the false-success as a fresh signup, producing a **second
`family_members` row with the same `auth_user_id`** for a real account
(priyanshumakwana920@gmail.com) — confirming that `getCurrentUserProfile()`'s
`.maybeSingle()` throws on >1 row match, and that nothing in the schema
prevents a second row with the same `auth_user_id` from being inserted.
Cleanup for the affected account is in progress, **not yet confirmed
complete** — see `04_current_risks.md`.

## Important database behavior to keep in mind
- The app assumes public read access to family members (and spouse links) for
  tree viewing.
- Claiming should only work for unclaimed profiles.
- Father/mother are still one-to-one link fields; spouse is now many-to-many via
  `spouse_relationships`, not a column on `family_members`.
- No database-level guard prevents a `father_id`/`mother_id` ancestry cycle
  from being created. An app-level guard (`wouldCreateAncestryCycle`) now
  blocks it at the one app entry point that could create one ("link
  existing" father/mother); the client-side pedigree *rendering* is
  separately cycle-safe against cycles that already exist in the data. See
  `04_current_risks.md`.
- Any new relation logic should preserve RLS constraints and not break public
  reads.
