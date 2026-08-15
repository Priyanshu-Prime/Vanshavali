// Read-only audit of the live Supabase Postgres schema, RLS policies, RPCs,
// and data integrity. Changes nothing. Run: npm run audit
//
// Ground truth for "what SHOULD be there" is
// supabase/migrations/001..004 — this script reports what's ACTUALLY there
// so drift between the two is visible, plus data-integrity checks that no
// migration can express (e.g. whether bad data already exists).

import pg from 'pg';
import { env, requireEnv } from './_env.mjs';

requireEnv(['SUPABASE_DB_URL']);

const { Client } = pg;

function section(title) {
  console.log(`\n${'='.repeat(70)}\n${title}\n${'='.repeat(70)}`);
}

async function main() {
  const client = new Client({ connectionString: env.SUPABASE_DB_URL });
  await client.connect();

  try {
    section('TABLES & COLUMNS (public schema)');
    const cols = await client.query(`
      SELECT table_name, column_name, data_type, is_nullable, column_default
      FROM information_schema.columns
      WHERE table_schema = 'public'
      ORDER BY table_name, ordinal_position;
    `);
    let lastTable = null;
    for (const row of cols.rows) {
      if (row.table_name !== lastTable) {
        console.log(`\n${row.table_name}`);
        lastTable = row.table_name;
      }
      console.log(
        `  ${row.column_name}: ${row.data_type}` +
        `${row.is_nullable === 'NO' ? ' NOT NULL' : ''}` +
        `${row.column_default ? ` DEFAULT ${row.column_default}` : ''}`
      );
    }

    section('CONSTRAINTS (primary key, foreign key, check, unique)');
    const constraints = await client.query(`
      SELECT tc.table_name, tc.constraint_type, tc.constraint_name,
             pg_get_constraintdef(pgc.oid) AS definition
      FROM information_schema.table_constraints tc
      JOIN pg_constraint pgc ON pgc.conname = tc.constraint_name
      WHERE tc.table_schema = 'public'
      ORDER BY tc.table_name, tc.constraint_type;
    `);
    for (const row of constraints.rows) {
      console.log(`${row.table_name} [${row.constraint_type}] ${row.constraint_name}: ${row.definition}`);
    }

    section('ROW LEVEL SECURITY — enabled?');
    const rls = await client.query(`
      SELECT relname AS table_name, relrowsecurity AS rls_enabled, relforcerowsecurity AS rls_forced
      FROM pg_class
      WHERE relnamespace = 'public'::regnamespace AND relkind = 'r'
      ORDER BY relname;
    `);
    for (const row of rls.rows) {
      console.log(`${row.table_name}: rls_enabled=${row.rls_enabled} rls_forced=${row.rls_forced}`);
    }

    section('RLS POLICIES (every table)');
    const policies = await client.query(`
      SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
      FROM pg_policies
      WHERE schemaname = 'public'
      ORDER BY tablename, cmd, policyname;
    `);
    for (const row of policies.rows) {
      console.log(`\n${row.tablename} [${row.cmd}] "${row.policyname}" (${row.permissive}, roles=${row.roles})`);
      if (row.qual) console.log(`  USING: ${row.qual}`);
      if (row.with_check) console.log(`  WITH CHECK: ${row.with_check}`);
    }

    section('FUNCTIONS / RPCs (public schema)');
    const funcs = await client.query(`
      SELECT p.proname,
             pg_get_function_identity_arguments(p.oid) AS args,
             p.prosecdef AS security_definer,
             pg_get_functiondef(p.oid) LIKE '%SET search_path%' AS has_search_path_set
      FROM pg_proc p
      WHERE p.pronamespace = 'public'::regnamespace
      ORDER BY p.proname;
    `);
    for (const row of funcs.rows) {
      console.log(
        `${row.proname}(${row.args}) ` +
        `security_definer=${row.security_definer} search_path_set=${row.has_search_path_set}`
      );
    }

    section('GRANTS on public.family_members / public.spouse_relationships');
    const grants = await client.query(`
      SELECT table_name, grantee, privilege_type
      FROM information_schema.role_table_grants
      WHERE table_schema = 'public'
        AND table_name IN ('family_members', 'spouse_relationships')
        AND grantee IN ('anon', 'authenticated', 'public')
      ORDER BY table_name, grantee, privilege_type;
    `);
    for (const row of grants.rows) {
      console.log(`${row.table_name} -> ${row.grantee}: ${row.privilege_type}`);
    }

    section('DATA INTEGRITY — duplicate profiles per auth_user_id (should be ZERO rows)');
    const dupes = await client.query(`
      SELECT auth_user_id, array_agg(id) AS member_ids, array_agg(first_name_en || ' ' || last_name_en) AS names, count(*)
      FROM public.family_members
      WHERE auth_user_id IS NOT NULL
      GROUP BY auth_user_id
      HAVING count(*) > 1;
    `);
    if (dupes.rows.length === 0) {
      console.log('None found — clean.');
    } else {
      console.log(`FOUND ${dupes.rows.length} auth_user_id(s) with multiple family_members rows:`);
      for (const row of dupes.rows) {
        console.log(`  auth_user_id=${row.auth_user_id} count=${row.count} ids=${row.member_ids} names=${row.names}`);
      }
    }

    section('DATA INTEGRITY — father_id/mother_id ancestry cycles (should be ZERO rows)');
    // Known gap: no DB-level guard prevents this today (see
    // docs/claude_handoff/04_current_risks.md). This just checks whether any
    // bad data already exists, walking up to 20 generations before giving up
    // (a real cycle will always trip the visited check well before that).
    const cycles = await client.query(`
      WITH RECURSIVE ancestry AS (
        SELECT id AS start_id, id AS current_id, father_id, mother_id, ARRAY[id] AS path, 1 AS depth
        FROM public.family_members
        UNION ALL
        SELECT a.start_id, fm.id, fm.father_id, fm.mother_id, a.path || fm.id, a.depth + 1
        FROM ancestry a
        JOIN public.family_members fm
          ON fm.id = COALESCE(a.father_id, a.mother_id)
        WHERE NOT fm.id = ANY(a.path) AND a.depth < 20
      )
      SELECT start_id, path
      FROM ancestry
      WHERE father_id = ANY(path) OR mother_id = ANY(path)
      LIMIT 10;
    `);
    if (cycles.rows.length === 0) {
      console.log('None found — clean (no cyclic father_id/mother_id chains in current data).');
    } else {
      console.log(`FOUND ${cycles.rows.length} potential cycle(s):`);
      for (const row of cycles.rows) {
        console.log(`  start=${row.start_id} path=${row.path}`);
      }
    }

    section('DATA INTEGRITY — spouse_relationships duplicate pair_key (should be ZERO; constraint should prevent this)');
    const spouseDupes = await client.query(`
      SELECT pair_key, count(*), array_agg(id) AS ids
      FROM public.spouse_relationships
      GROUP BY pair_key
      HAVING count(*) > 1;
    `);
    console.log(spouseDupes.rows.length === 0 ? 'None found — clean.' : JSON.stringify(spouseDupes.rows, null, 2));

    section('DATA INTEGRITY — invite_code set on an already-CLAIMED profile (should be ZERO; claim RPCs clear it)');
    const staleCodes = await client.query(`
      SELECT id, first_name_en, last_name_en, invite_code, auth_user_id
      FROM public.family_members
      WHERE invite_code IS NOT NULL AND auth_user_id IS NOT NULL;
    `);
    console.log(staleCodes.rows.length === 0 ? 'None found — clean.' : JSON.stringify(staleCodes.rows, null, 2));

    section('DATA INTEGRITY — empty first_name_en (defensive-gap check; app validates this, but direct SQL inserts would not)');
    const emptyNames = await client.query(`
      SELECT id, auth_user_id FROM public.family_members WHERE first_name_en = '' OR last_name_en = '';
    `);
    console.log(emptyNames.rows.length === 0 ? 'None found — clean.' : JSON.stringify(emptyNames.rows, null, 2));

    section('DATA INTEGRITY — spouse_id column should NOT exist on family_members (dropped in 003)');
    const spouseIdCol = await client.query(`
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'family_members' AND column_name = 'spouse_id';
    `);
    console.log(spouseIdCol.rows.length === 0
      ? 'Confirmed absent — migration 003 fully applied.'
      : 'STILL PRESENT — migration 003 did not fully apply, or was re-added by accident.');

    section('ROW COUNTS');
    const counts = await client.query(`
      SELECT
        (SELECT count(*) FROM public.family_members) AS family_members,
        (SELECT count(*) FROM public.family_members WHERE auth_user_id IS NOT NULL) AS claimed,
        (SELECT count(*) FROM public.family_members WHERE auth_user_id IS NULL) AS unclaimed_placeholders,
        (SELECT count(*) FROM public.spouse_relationships) AS spouse_relationships;
    `);
    console.log(counts.rows[0]);

    console.log('\nAudit complete.');
  } finally {
    await client.end();
  }
}

main().catch((err) => {
  console.error('Audit failed:', err);
  process.exit(1);
});
