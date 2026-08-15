// One-off fix: this Supabase project doesn't expose the old-style direct
// database host (db.<ref>.supabase.co) — it doesn't resolve via DNS at all.
// Only the pooler endpoint works (confirmed via the Supabase CLI's own
// connection attempt: aws-0-ap-northeast-1.pooler.supabase.com, username
// postgres.<project-ref>). Rewrites SUPABASE_DB_URL in .env.local to the
// pooler format, reusing the password already present in
// SUPABASE_DB_PASSWORD. Never prints the password.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const localPath = path.resolve(__dirname, '../../supabase/.env.local');

const PROJECT_REF = 'lsmualpdhtpdpdhfmdmj';
const POOLER_HOST = 'aws-0-ap-northeast-1.pooler.supabase.com';
const POOLER_PORT = 5432; // session pooler — behaves like a direct connection, safest for a general-purpose script client (vs. 6543 transaction pooler, which can have prepared-statement quirks)

let lines = fs.readFileSync(localPath, 'utf8').split(/\r?\n/);

const pwLine = lines.find((l) => l.startsWith('SUPABASE_DB_PASSWORD='));
if (!pwLine) {
  console.error('SUPABASE_DB_PASSWORD not found in .env.local — nothing to do.');
  process.exit(1);
}
const password = pwLine.slice('SUPABASE_DB_PASSWORD='.length);

const newDbUrl = `SUPABASE_DB_URL=postgresql://postgres.${PROJECT_REF}:${password}@${POOLER_HOST}:${POOLER_PORT}/postgres`;

const idx = lines.findIndex((l) => l.startsWith('SUPABASE_DB_URL='));
if (idx >= 0) {
  lines[idx] = newDbUrl;
} else {
  lines.push(newDbUrl);
}

fs.writeFileSync(localPath, lines.join('\n'));
console.log('SUPABASE_DB_URL rewritten to use the pooler host (value not shown).');
