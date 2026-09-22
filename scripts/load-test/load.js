// k6 load test for Vanshavali's hot read RPCs.
//
// Why k6 (not a Dart script): lighter, purpose-built for concurrency, hits the
// same REST/RPC surface the app uses without dragging in the Flutter runtime.
//
// Realistic scale: ~500 registered users is NOT 500 concurrent RPCs. A village
// app's realistic peak concurrency is ~20-50. Testing at 500 VUs would just
// load-test Supabase's free-tier abuse throttle, not the app. So we ramp to 50.
//
// Run:
//   SUPABASE_REF=xxxx SUPABASE_ANON_KEY=eyJ... ROOT_MEMBER_ID=<uuid> k6 run load.js
//
// Notes:
//  - get_ego_network is granted to anon (migration 003) → runs with the anon key.
//  - get_connected_tree is granted to `authenticated` only (migration 014). To
//    exercise it, either pass a signed-in user JWT as SUPABASE_JWT (used as the
//    Authorization bearer) or run against the local e2e stack (scripts/e2e) where
//    you control auth. Without a JWT it will 401 — that check is skipped then.
//  - The anon key is already public (shipped in the APK), so using it here is fine.

import http from 'k6/http';
import { check, sleep } from 'k6';

const REF = __ENV.SUPABASE_REF;
const ANON = __ENV.SUPABASE_ANON_KEY;
const ROOT = __ENV.ROOT_MEMBER_ID;
const JWT = __ENV.SUPABASE_JWT || ANON; // fall back to anon for the anon-granted RPC

if (!REF || !ANON || !ROOT) {
  throw new Error('Set SUPABASE_REF, SUPABASE_ANON_KEY, ROOT_MEMBER_ID env vars.');
}

const base = `https://${REF}.supabase.co/rest/v1/rpc`;
const anonHeaders = { apikey: ANON, Authorization: `Bearer ${ANON}`, 'Content-Type': 'application/json' };
const authHeaders = { apikey: ANON, Authorization: `Bearer ${JWT}`, 'Content-Type': 'application/json' };

export const options = {
  stages: [
    { duration: '30s', target: 20 }, // ramp
    { duration: '1m', target: 50 },  // realistic village peak
    { duration: '30s', target: 0 },  // ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<800'], // 95% of reads under 800ms
    checks: ['rate>0.98'],
  },
};

export default function () {
  // Ego network (anon-granted) — the tree's core read.
  const ego = http.post(`${base}/get_ego_network`,
    JSON.stringify({ center_member_id: ROOT }), { headers: anonHeaders });
  check(ego, { 'ego 200': (r) => r.status === 200 });

  // Connected tree (auth-only) — only meaningful with a real JWT.
  if (__ENV.SUPABASE_JWT) {
    const tree = http.post(`${base}/get_connected_tree`,
      JSON.stringify({ root: ROOT }), { headers: authHeaders });
    check(tree, { 'tree 200': (r) => r.status === 200 });
  }

  sleep(1);
}
