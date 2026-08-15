// One-off utility: moves real values that landed in the tracked
// .env.local.example (a mistake — should only ever contain placeholders)
// into the actual gitignored .env.local, then resets .example back to
// clean placeholder text. Never prints any value to stdout.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const exPath = path.resolve(__dirname, '../../supabase/.env.local.example');
const localPath = path.resolve(__dirname, '../../supabase/.env.local');

const PLACEHOLDER_MARKERS = ['YOUR_DB_PASSWORD', 'YOUR_SERVICE_ROLE_KEY', 'YOUR_ACCESS_TOKEN'];

function parseLines(content) {
  return content.split(/\r?\n/);
}

function isRealValue(line) {
  const eq = line.indexOf('=');
  if (eq === -1) return false;
  const value = line.slice(eq + 1);
  return value.length > 0 && !PLACEHOLDER_MARKERS.some((m) => value.includes(m));
}

function keyOf(line) {
  return line.slice(0, line.indexOf('='));
}

const exLines = parseLines(fs.readFileSync(exPath, 'utf8'));
const realLinesFromExample = exLines.filter(
  (l) => /^[A-Z_]+=/.test(l) && isRealValue(l)
);

if (realLinesFromExample.length === 0) {
  console.log('No real values found in .env.local.example — nothing to move.');
  process.exit(0);
}

const movedKeys = realLinesFromExample.map(keyOf);
console.log(`Moving ${movedKeys.length} real value(s) from .env.local.example to .env.local: ${movedKeys.join(', ')}`);

// Update/insert into .env.local
let localLines = parseLines(fs.readFileSync(localPath, 'utf8'));
for (const realLine of realLinesFromExample) {
  const key = keyOf(realLine);
  const idx = localLines.findIndex((l) => l.startsWith(`${key}=`));
  if (idx >= 0) {
    localLines[idx] = realLine;
  } else {
    localLines.push(realLine);
  }
}
fs.writeFileSync(localPath, localLines.join('\n'));

// Reset those same keys in .env.local.example back to their placeholder form
// by reading the placeholder pairs straight from git-diff-known text — since
// we don't have the original placeholder values handy generically, just
// regenerate the whole known-good template deterministically instead.
const CLEAN_TEMPLATE = `# Copy this file to supabase/.env.local and fill in the real values.
# supabase/.env.local is gitignored — it will never be committed.
# Never paste these values into chat; put them only in this file.
#
# IMPORTANT: this file (.env.local.example) is the TEMPLATE — it IS tracked
# in git. Only supabase/.env.local (no ".example") is gitignored. Always
# double-check which file is open before pasting a real secret in — check
# the tab/title bar says ".env.local", NOT ".env.local.example", before
# pasting anything.

# Already public (shipped inside the compiled app, see lib/config/app_config.dart)
# — pre-filled, no action needed unless the project changes.
SUPABASE_URL=https://lsmualpdhtpdpdhfmdmj.supabase.co
SUPABASE_ANON_KEY=sb_publishable_sihPTWjfbjQeqvY1OqI8Uw_lnfcMbye

# SECRET — Project Settings -> Database -> Connection string -> URI (the
# "postgres" user's password you set when creating the project, or reset it
# there if forgotten). Used by scripts/backend_audit/*.mjs (via the \`pg\` package).
SUPABASE_DB_URL=postgresql://postgres:YOUR_DB_PASSWORD@db.lsmualpdhtpdpdhfmdmj.supabase.co:5432/postgres

# SECRET — same password as in SUPABASE_DB_URL above, just as a standalone
# value (the Supabase CLI wants it separately, not parsed out of a URL).
# Used for non-interactive \`supabase link\`/\`supabase db ...\` commands.
SUPABASE_DB_PASSWORD=YOUR_DB_PASSWORD

# SECRET — Project Settings -> API -> Project API keys -> service_role.
# This key bypasses Row Level Security — treat it like a root password.
# Used by scripts/backend_audit/rls_behavior_test.mjs (admin auth API, test
# user create/delete).
SUPABASE_SERVICE_ROLE_KEY=YOUR_SERVICE_ROLE_KEY

# SECRET — Supabase Dashboard -> Account (top-right avatar) -> Access Tokens
# -> Generate new token. Lets the Supabase CLI authenticate non-interactively
# (no browser login flow) for \`supabase link\`, \`supabase migration list\`,
# etc. Treat like a password to your whole Supabase account, not just this
# project — scope/revoke it in the dashboard if you ever stop using it here.
SUPABASE_ACCESS_TOKEN=YOUR_ACCESS_TOKEN
`;
fs.writeFileSync(exPath, CLEAN_TEMPLATE);
console.log('Reset .env.local.example to clean placeholder text.');
