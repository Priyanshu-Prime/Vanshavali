-- Seed data for the LOCAL Supabase stack only (loaded automatically on
-- `supabase db reset`, per config.toml's db.seed.sql_paths). Never applied to
-- the hosted alpha/production project.
--
-- Purpose: give the E2E rig deterministic, unclaimed placeholder profiles with
-- KNOWN invite codes, so claim-by-code flows are repeatable across runs. Auth
-- users are NOT seeded here (they're created through the real signup flow by
-- the tests themselves); these are relative-created "ghost" rows only, exactly
-- the shape the invite/claim system is designed around.

-- Fixed UUIDs so integration tests can reference specific rows if needed.
insert into public.family_members
  (id, auth_user_id, first_name_en, last_name_en, first_name_gu, last_name_gu,
   gender, is_alive, village_origin, invite_code)
values
  -- A claimable placeholder with a known code (happy-path claim test).
  ('00000000-0000-0000-0000-0000000000a1', null,
   'Ramesh', 'Patel', 'રમેશ', 'પટેલ', 'Male', true, 'Anand', 'TEST01'),

  -- A second claimable placeholder (used to test a distinct code / second
  -- tester without colliding with the first).
  ('00000000-0000-0000-0000-0000000000a2', null,
   'Sita', 'Patel', 'સીતા', 'પટેલ', 'Female', true, 'Anand', 'TEST02'),

  -- An already-"burned" code scenario: this placeholder's code is set but the
  -- row is pre-claimed by nobody yet; the single-use-code regression test
  -- claims TEST03 once, then asserts a second claim of TEST03 fails. Kept as a
  -- separate row so it never interferes with TEST01/TEST02.
  ('00000000-0000-0000-0000-0000000000a3', null,
   'Mohan', 'Patel', 'મોહન', 'પટેલ', 'Male', true, 'Anand', 'TEST03');

-- A tiny lineage for tree/pedigree rendering tests: a father placeholder and a
-- child placeholder linked to him. Both unclaimed; a test can claim the child
-- (code TEST04) and expect the father to appear in the ego network.
insert into public.family_members
  (id, auth_user_id, first_name_en, last_name_en, gender, is_alive, invite_code, father_id)
values
  ('00000000-0000-0000-0000-0000000000b1', null,
   'Grandfather', 'Patel', 'Male', false, null, null),
  ('00000000-0000-0000-0000-0000000000b2', null,
   'Father', 'Patel', 'Male', true, null, '00000000-0000-0000-0000-0000000000b1'),
  ('00000000-0000-0000-0000-0000000000b3', null,
   'Child', 'Patel', 'Male', true, 'TEST04', '00000000-0000-0000-0000-0000000000b2');
