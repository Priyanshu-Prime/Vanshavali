// Behavioral RLS/RPC test suite. Creates disposable, clearly-labeled test
// accounts, exercises policies/RPCs as real authenticated identities (not
// admin-bypassed — this is what actually proves RLS works, not just that
// the SQL text looks right), then deletes everything it created.
//
// Run: npm run rls-test
//
// Test accounts use the `example.invalid` TLD (reserved by RFC 2606,
// guaranteed never to resolve/deliver) with a `vanshavali-audit-test+`
// prefix and a run-specific timestamp, so they're unmistakably throwaway
// and never collide with a real user's email.

import { createClient } from '@supabase/supabase-js';
import pg from 'pg';
import { env, requireEnv } from './_env.mjs';

requireEnv(['SUPABASE_URL', 'SUPABASE_ANON_KEY', 'SUPABASE_DB_URL', 'SUPABASE_SERVICE_ROLE_KEY']);

const RUN_ID = Date.now();
const TEST_PASSWORD = `AuditTest!${RUN_ID}`;

function testEmail(label) {
  return `vanshavali-audit-test+${label}-${RUN_ID}@example.invalid`;
}

// ---- tiny test harness ----
let passed = 0;
let failed = 0;
const findings = [];

function report(name, ok, detail) {
  if (ok) {
    passed++;
    console.log(`  PASS  ${name}`);
  } else {
    failed++;
    console.log(`  FAIL  ${name}${detail ? ` — ${detail}` : ''}`);
  }
}

function finding(name, detail) {
  findings.push({ name, detail });
  console.log(`  FINDING  ${name} — ${detail}`);
}

function section(title) {
  console.log(`\n${'='.repeat(70)}\n${title}\n${'='.repeat(70)}`);
}

// ---- setup helpers ----
const admin = createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

async function createTestUser(label) {
  const email = testEmail(label);
  const { data, error } = await admin.auth.admin.createUser({
    email,
    password: TEST_PASSWORD,
    email_confirm: true, // skip email delivery entirely — this is a disposable test account
  });
  if (error) throw new Error(`createTestUser(${label}) failed: ${error.message}`);
  return { id: data.user.id, email };
}

async function actorClientFor(email) {
  const client = createClient(env.SUPABASE_URL, env.SUPABASE_ANON_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { error } = await client.auth.signInWithPassword({ email, password: TEST_PASSWORD });
  if (error) throw new Error(`Sign-in failed for ${email}: ${error.message}`);
  return client;
}

async function insertMember(client, { firstName, authUserId = null, fatherId = null, motherId = null }) {
  const { data, error } = await client
    .from('family_members')
    .insert({
      first_name_en: firstName,
      last_name_en: 'AuditTest',
      gender: 'Other',
      auth_user_id: authUserId,
      father_id: fatherId,
      mother_id: motherId,
    })
    .select()
    .single();
  return { data, error };
}

async function main() {
  const created = { userIds: [], memberIds: [], spouseLinkIds: [] };

  try {
    section('SETUP — creating disposable test users');
    const userA = await createTestUser('userA');
    const userB = await createTestUser('userB');
    const userC = await createTestUser('userC'); // stays profile-less until the claim_profile tests
    const userD = await createTestUser('userD'); // stays profile-less until the claim_profile_by_code tests
    created.userIds.push(userA.id, userB.id, userC.id, userD.id);
    console.log(`Created: ${userA.email}, ${userB.email}, ${userC.email}, ${userD.email}`);

    const clientA = await actorClientFor(userA.email);
    const clientB = await actorClientFor(userB.email);
    const clientC = await actorClientFor(userC.email);
    const clientD = await actorClientFor(userD.email);

    section('family_members — own-profile creation (baseline, should always work)');
    {
      const { data, error } = await insertMember(clientA, { firstName: 'A', authUserId: userA.id });
      report('userA can create their own profile', !error, error?.message);
      if (data) created.memberIds.push(data.id);
    }
    {
      const { data, error } = await insertMember(clientB, { firstName: 'B', authUserId: userB.id });
      report('userB can create their own profile', !error, error?.message);
      if (data) created.memberIds.push(data.id);
    }

    section('family_members — INSERT policy: can an authenticated user impersonate someone else?');
    {
      // userA already has a profile; try to insert a SECOND row claiming to
      // be userB (auth_user_id = userB.id). Per the 001 migration's INSERT
      // policy (`WITH CHECK (true)`), nothing at the SQL level stops this —
      // only the app's own client-side logic avoids doing it. This test
      // checks whether that's actually exploitable via a direct API call.
      const { data, error } = await insertMember(clientA, { firstName: 'Impersonated', authUserId: userB.id });
      if (!error) {
        finding(
          'INSERT policy allows setting auth_user_id to a DIFFERENT real user\'s id',
          `userA successfully inserted a family_members row (id=${data.id}) with auth_user_id=userB's id. ` +
          `The INSERT policy's WITH CHECK is unconditionally true — it never validates auth_user_id against auth.uid(). ` +
          `This doesn't let userA control userB's real profile (UPDATE policy still protects that), but it does let ` +
          `any authenticated user plant a fake row that LOOKS claimed by an arbitrary real user. Recommend tightening ` +
          `the INSERT policy to WITH CHECK (auth_user_id = auth.uid() OR auth_user_id IS NULL), mirroring the UPDATE policy.`
        );
        created.memberIds.push(data.id);
      } else {
        report('INSERT policy blocks setting auth_user_id to another user', true);
      }
    }

    section('family_members — UPDATE policy');
    {
      const { error } = await clientA
        .from('family_members')
        .update({ last_name_en: 'HijackedByA' })
        .eq('auth_user_id', userB.id);
      const { data: check } = await admin.from('family_members').select('last_name_en').eq('auth_user_id', userB.id).single();
      report(
        'userA cannot update userB\'s claimed profile',
        check?.last_name_en !== 'HijackedByA',
        `last_name_en after attempted update: ${check?.last_name_en}`
      );
    }
    let placeholder1Id;
    {
      const { data } = await insertMember(clientA, { firstName: 'Placeholder1' }); // unclaimed
      placeholder1Id = data?.id;
      if (data) created.memberIds.push(data.id);
      const { error } = await clientB.from('family_members').update({ current_city: 'EditedByB' }).eq('id', placeholder1Id);
      report('userB CAN update an unclaimed placeholder (by design)', !error, error?.message);
    }

    section('family_members — DELETE policy');
    let placeholder2Id;
    {
      const { data } = await insertMember(clientA, { firstName: 'Placeholder2' }); // unclaimed, created by A
      placeholder2Id = data?.id;
      const { error } = await clientB.from('family_members').delete().eq('id', placeholder2Id);
      if (!error) {
        finding(
          'DELETE policy lets any authenticated user delete ANY unclaimed placeholder, not just one they created',
          `userB deleted a placeholder userA created, with no relationship between them. Policy is ` +
          `USING (auth_user_id IS NULL) with no ownership/relationship check. May be intentional ` +
          `(placeholder cleanup is low-stakes, no real person's data is destroyed), but flagging since it ` +
          `wasn't behaviorally confirmed before.`
        );
      } else {
        report('DELETE policy restricts placeholder deletion to some ownership check', true);
        created.memberIds.push(placeholder2Id); // wasn't deleted, still needs cleanup
      }
    }
    {
      const { error } = await clientB.from('family_members').delete().eq('auth_user_id', userA.id);
      const { data: stillThere } = await admin.from('family_members').select('id').eq('auth_user_id', userA.id).maybeSingle();
      report('userB cannot delete userA\'s claimed profile', !!stillThere, 'row should still exist');
    }

    section('claim_profile RPC');
    let placeholderForClaim;
    {
      const { data } = await insertMember(clientA, { firstName: 'ForClaiming' });
      placeholderForClaim = data?.id;
      if (data) created.memberIds.push(data.id);
    }
    {
      const { data, error } = await clientC.rpc('claim_profile', { profile_id: placeholderForClaim });
      report('userC (no profile yet) can claim an unclaimed placeholder', !error && data, error?.message);
    }
    {
      const { data: secondPlaceholder } = await insertMember(clientA, { firstName: 'SecondPlaceholder' });
      if (secondPlaceholder) created.memberIds.push(secondPlaceholder.id);
      const { error } = await clientC.rpc('claim_profile', { profile_id: secondPlaceholder?.id });
      report('userC (now HAS a profile) is blocked from claiming a second one', !!error, 'expected "User already has a profile"');
    }
    {
      const { error } = await clientA.rpc('claim_profile', { profile_id: placeholderForClaim });
      report('Re-claiming an already-claimed profile fails', !!error, 'expected "Profile not found or already claimed"');
    }

    section('claim_profile_by_code RPC');
    const inviteCode = `AT${String(RUN_ID).slice(-4)}`;
    let placeholderForCode;
    {
      const { data } = await insertMember(clientA, { firstName: 'ForCodeClaiming' });
      placeholderForCode = data?.id;
      if (data) created.memberIds.push(data.id);
      // Mirrors what the app does client-side (a direct update, not an RPC) —
      // legal under the UPDATE policy since the row is unclaimed.
      const { error: codeSetError } = await clientA.from('family_members').update({ invite_code: inviteCode }).eq('id', placeholderForCode);
      report('Setting an invite_code on an unclaimed placeholder succeeds', !codeSetError, codeSetError?.message);
    }
    {
      const { data, error } = await clientD.rpc('claim_profile_by_code', { code: inviteCode });
      report('userD (no profile) can claim via invite code', !error && data, error?.message);
    }
    {
      const { data: afterClaim } = await admin.from('family_members').select('invite_code').eq('id', placeholderForCode).single();
      report('invite_code is cleared after a successful claim', afterClaim?.invite_code === null, `invite_code=${afterClaim?.invite_code}`);
    }
    {
      const { error } = await clientA.rpc('claim_profile_by_code', { code: inviteCode });
      report('Reusing an already-consumed invite code fails', !!error, 'expected "Invalid or already claimed invite code"');
    }

    section('spouse_relationships — INSERT policy (migration 004 tightening)');
    let strangerPlaceholder;
    {
      const { data } = await insertMember(clientB, { firstName: 'StrangerPlaceholder' }); // created by B, unrelated to A
      strangerPlaceholder = data?.id;
      if (data) created.memberIds.push(data.id);
    }
    {
      // userA tries to link userB's CLAIMED profile to a placeholder userA has
      // no relationship to — neither side is userA's own profile. This is
      // exactly the gap 003 had and 004 was written to close.
      const { data: userBMember } = await admin.from('family_members').select('id').eq('auth_user_id', userB.id).single();
      const { error } = await clientA.from('spouse_relationships').insert({
        member_id: userBMember.id,
        spouse_id: strangerPlaceholder,
      });
      report(
        'userA CANNOT link two people neither of which is their own profile (004 fix holds)',
        !!error,
        error ? undefined : 'INSERT succeeded — migration 004 is not actually enforced live'
      );
    }
    let ownSpouseLinkId;
    {
      const { data: userAMember } = await admin.from('family_members').select('id').eq('auth_user_id', userA.id).single();
      const { data, error } = await clientA.from('spouse_relationships').insert({
        member_id: userAMember.id,
        spouse_id: placeholder1Id,
      }).select().single();
      report('userA CAN link their own profile to a placeholder', !error, error?.message);
      if (data) { ownSpouseLinkId = data.id; created.spouseLinkIds.push(data.id); }
    }
    {
      // Two unclaimed placeholders, neither is userA's own profile — should
      // still succeed under 004's "both sides unclaimed" clause.
      const { data: placeholder3 } = await insertMember(clientA, { firstName: 'Placeholder3' });
      if (placeholder3) created.memberIds.push(placeholder3.id);
      const { data, error } = await clientA.from('spouse_relationships').insert({
        member_id: strangerPlaceholder,
        spouse_id: placeholder3?.id,
      }).select().single();
      report('userA CAN link two unrelated unclaimed placeholders to each other', !error, error?.message);
      if (data) created.spouseLinkIds.push(data.id);
    }

    section('spouse_relationships — duplicate pair_key constraint');
    {
      const { data: userAMember } = await admin.from('family_members').select('id').eq('auth_user_id', userA.id).single();
      const { error: dupError } = await clientA.from('spouse_relationships').insert({
        member_id: userAMember.id,
        spouse_id: placeholder1Id,
      });
      report('Inserting the exact same pair twice is rejected', !!dupError, dupError ? undefined : 'duplicate insert succeeded');

      const { error: reversedError } = await clientA.from('spouse_relationships').insert({
        member_id: placeholder1Id,
        spouse_id: userAMember.id, // same pair, reversed
      });
      report('Inserting the same pair REVERSED is also rejected (pair_key normalization works)', !!reversedError, reversedError ? undefined : 'reversed duplicate succeeded');
    }

    section('spouse_relationships — DELETE policy (migration 004 tightening)');
    {
      const { data: userBMember } = await admin.from('family_members').select('id').eq('auth_user_id', userB.id).single();
      // Link strangerPlaceholder to userB via admin (bypassing RLS, just to
      // set up the fixture) so we can test whether userA can delete it.
      const { data: setupLink } = await admin.from('spouse_relationships').insert({
        member_id: userBMember.id,
        spouse_id: strangerPlaceholder,
      }).select().single();
      if (setupLink) created.spouseLinkIds.push(setupLink.id);

      const { error } = await clientA.from('spouse_relationships').delete().eq('id', setupLink?.id);
      const { data: stillExists } = await admin.from('spouse_relationships').select('id').eq('id', setupLink?.id).maybeSingle();
      report(
        'userA CANNOT delete a spouse link between two people neither of which is their own profile',
        !!stillExists,
        stillExists ? undefined : 'DELETE succeeded — migration 004 DELETE policy is not actually enforced live'
      );
    }
    {
      const { error } = await clientA.from('spouse_relationships').delete().eq('id', ownSpouseLinkId);
      report('userA CAN delete their own spouse link', !error, error?.message);
      if (!error) created.spouseLinkIds = created.spouseLinkIds.filter((id) => id !== ownSpouseLinkId);
    }

  } finally {
    section('CLEANUP — deleting everything this run created');
    const pgClient = new pg.Client({ connectionString: env.SUPABASE_DB_URL });
    await pgClient.connect();
    try {
      if (created.spouseLinkIds.length > 0) {
        await pgClient.query('DELETE FROM public.spouse_relationships WHERE id = ANY($1::uuid[])', [created.spouseLinkIds]);
      }
      // Also sweep any spouse_relationships rows touching test member ids,
      // in case a test left one behind under an id not tracked above.
      if (created.memberIds.length > 0) {
        await pgClient.query(
          'DELETE FROM public.spouse_relationships WHERE member_id = ANY($1::uuid[]) OR spouse_id = ANY($1::uuid[])',
          [created.memberIds]
        );
        await pgClient.query('DELETE FROM public.family_members WHERE id = ANY($1::uuid[])', [created.memberIds]);
      }
      // Sweep by auth_user_id too, in case a test created a row not pushed to memberIds.
      if (created.userIds.length > 0) {
        await pgClient.query('DELETE FROM public.family_members WHERE auth_user_id = ANY($1::uuid[])', [created.userIds]);
      }
      console.log(`Deleted ${created.memberIds.length} tracked family_members row(s), ${created.spouseLinkIds.length} tracked spouse_relationships row(s), plus any untracked rows matching test user/member ids.`);
    } finally {
      await pgClient.end();
    }

    for (const userId of created.userIds) {
      const { error } = await admin.auth.admin.deleteUser(userId);
      if (error) console.error(`  Failed to delete test auth user ${userId}: ${error.message}`);
    }
    console.log(`Deleted ${created.userIds.length} test auth user(s).`);

    section('SUMMARY');
    console.log(`${passed} passed, ${failed} failed, ${findings.length} finding(s) for follow-up.`);
    if (findings.length > 0) {
      console.log('\nFindings (behavior confirmed live, not necessarily bugs — review each):');
      findings.forEach((f, i) => console.log(`  ${i + 1}. ${f.name}\n     ${f.detail}`));
    }
    if (failed > 0) process.exitCode = 1;
  }
}

main().catch((err) => {
  console.error('Test run crashed:', err);
  process.exitCode = 1;
});
