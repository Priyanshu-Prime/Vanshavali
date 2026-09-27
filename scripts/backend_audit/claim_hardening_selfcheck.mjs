// Self-check for migration 018 (claim + link hardening). LOCAL ONLY.
//
// Applies supabase/migrations/018_claim_and_link_hardening.sql to the local
// Supabase Postgres, then runs every scenario inside ONE transaction that is
// always rolled back -- no test data survives. Hard-coded to the local rig on
// purpose (never reads _env.mjs, so it can't touch prod).
//
//   cd scripts/backend_audit && npm install && node claim_hardening_selfcheck.mjs
import fs from 'fs';
import pg from 'pg';

const LOCAL = 'postgresql://postgres:postgres@127.0.0.1:55322/postgres';
const sql = fs.readFileSync(
  new URL('../../supabase/migrations/018_claim_and_link_hardening.sql', import.meta.url), 'utf8');

const c = new pg.Client({ connectionString: LOCAL });
await c.connect();
let failures = 0;
const ok = (cond, msg) => { console.log(`${cond ? 'PASS' : 'FAIL'}  ${msg}`); if (!cond) failures++; };

const q = async (text, params) => (await c.query(text, params)).rows;
const as = async (uid) => {
  await c.query('RESET ROLE');
  await c.query("SELECT set_config('request.jwt.claims', $1, true)",
    [JSON.stringify({ sub: uid, role: 'authenticated' })]);
  await c.query('SET LOCAL ROLE authenticated');
};
const asAdmin = async (uid = null) => {
  await c.query('RESET ROLE');
  await c.query("SELECT set_config('request.jwt.claims', $1, true)",
    [uid ? JSON.stringify({ sub: uid }) : '']);
};
const throws = async (fn, re) => {
  await c.query('SAVEPOINT sp');
  try { await fn(); await c.query('RELEASE SAVEPOINT sp'); return false; }
  catch (e) { await c.query('ROLLBACK TO SAVEPOINT sp'); return re.test(e.message) || e.message; }
};

await c.query(sql); // idempotent (CREATE OR REPLACE / DROP IF EXISTS)
console.log('applied 018');

await c.query('BEGIN');
try {
  const uid = {};
  for (const n of ['g', 's', 'x', 'a', 'r', 'o']) {
    uid[n] = (await q(
      `INSERT INTO auth.users (id, email, aud, role) VALUES (gen_random_uuid(), $1, 'authenticated', 'authenticated') RETURNING id`,
      [`selfcheck_${n}_${Date.now()}@example.test`]))[0].id;
  }
  const add = async (first, { auth = null, father = null, mother = null, village = null, gender = 'Male' } = {}) =>
    (await q(`INSERT INTO public.family_members (first_name_en, last_name_en, gender, auth_user_id, father_id, mother_id, village_origin)
              VALUES ($1, 'Selfcheckpatel', $2, $3, $4, $5, $6) RETURNING id`,
      [first, gender, auth, father, mother, village]))[0].id;

  await asAdmin();
  // G (claimed) -> F (placeholder) -> T (placeholder), S (claimed sibling of T)
  const G = await add('Grandpa', { auth: uid.g });
  const A = await add('Aunt', { auth: uid.a, father: G, gender: 'Female' });
  const F = await add('Father', { father: G });
  const T = await add('Target', { father: F });
  await add('Sibling', { auth: uid.s, father: F });
  await add('Stranger', { auth: uid.x });
  // P2: only a grandparent (G) is registered
  const F2 = await add('Father2', { father: G });
  const P2 = await add('Remote', { father: F2 });
  // P3: no registered relative at all; created by O
  await add('Creator', { auth: uid.o });
  await asAdmin(uid.o);
  const P3 = await add('Orphan');
  await asAdmin();

  const approver = async (who, target) => {
    await as(uid[who]);
    const r = (await q('SELECT public.is_claim_approver($1) AS v', [target]))[0].v;
    await asAdmin();
    return r;
  };

  // ---- Part 3: approver rings
  ok(await approver('s', T) === true, 'ring1: registered sibling may approve');
  ok(await approver('x', T) === false, 'stranger may NOT approve');
  ok(await approver('a', T) === false, 'aunt blocked while a ring1 relative is registered');
  ok(await approver('g', T) === false, 'grandparent blocked while a ring1 relative is registered');
  ok(await approver('g', P2) === true, 'ring2: grandparent may approve when ring1 has nobody registered');
  ok(await approver('a', P2) === true, 'ring2: aunt may approve when ring1 has nobody registered');
  ok(await approver('x', P2) === false, 'ring2: stranger still blocked');
  ok(await approver('o', P3) === true, 'ring3: placeholder creator may approve an isolated placeholder');
  ok(await approver('s', P3) === false, 'ring3: non-creator blocked');

  // ---- Claim flow end to end
  await as(uid.r);
  const req = (await q('SELECT (public.request_claim($1)).id AS id', [T]))[0].id;
  await as(uid.x);
  ok((await q("SELECT 1 FROM public.merge_requests WHERE kind='claim_request'")).length === 0,
    'RLS: stranger cannot read the claim request');
  ok((await q('SELECT * FROM public.pending_claim_requests()')).length === 0, 'stranger inbox empty');
  let e = await throws(() => q('SELECT public.approve_claim_request($1)', [req]), /not allowed to approve/);
  ok(e === true, `stranger approve rejected (${e})`);
  e = await throws(() => q('SELECT public.reject_claim_request($1)', [req]), /not allowed to reject/);
  ok(e === true, `stranger reject rejected (${e})`);
  await as(uid.s);
  const inbox = await q('SELECT * FROM public.pending_claim_requests()');
  ok(inbox.length === 1 && inbox[0].request_id === req, 'sibling inbox shows the request');
  ok(inbox[0]?.requester_email?.startsWith('selfcheck_r_'), `inbox carries requester_email (${inbox[0]?.requester_email})`);
  await q('SELECT public.approve_claim_request($1)', [req]);
  await asAdmin();
  ok((await q('SELECT auth_user_id FROM public.family_members WHERE id=$1', [T]))[0].auth_user_id === uid.r,
    'approved claim links the requester');

  // ---- Part 1: no re-parenting
  const F3 = await add('OtherFather');
  const M = await add('Mother', { gender: 'Female' });
  const C = await add('Child', { father: F });
  await as(uid.s);
  e = await throws(() => q('SELECT public.set_member_parents($1, $2)', [C, F3]), /vanshavali_parent_already_set/);
  ok(e === true, `replacing an existing father is refused (${e})`);
  e = await throws(() => q('SELECT public.set_member_parents($1, $2)', [C, F]), /./);
  ok(e === false, 'same father again is a no-op');
  e = await throws(() => q('SELECT public.set_member_parents($1, NULL, $2)', [C, M]), /./);
  ok(e === false, 'filling an empty mother slot works');
  await asAdmin();
  const row = (await q('SELECT father_id, mother_id FROM public.family_members WHERE id=$1', [C]))[0];
  ok(row.father_id === F && row.mother_id === M, 'child keeps original father, gains mother');

  // ---- Part 2: name + gender alone is not a duplicate
  await add('Rameshselfcheck', { village: 'Selfcheckvillage' });
  await as(uid.s);
  const dup = (a) => q(`SELECT member->>'first_name_en' AS n FROM public.find_duplicate_candidates(
      'Rameshselfcheck', 'Selfcheckpatel', p_gender => 'Male', p_village => $1)`, [a]);
  ok((await dup(null)).length === 0, 'name + gender only -> no candidate');
  ok((await dup('Selfcheckvillage')).some((r) => r.n === 'Rameshselfcheck'), 'name + gender + village -> candidate');
} finally {
  await c.query('ROLLBACK');
  await c.end();
}
console.log(failures ? `\n${failures} FAILED` : '\nALL PASS');
process.exit(failures ? 1 : 0);
