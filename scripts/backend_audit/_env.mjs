// Shared credential loader. Reads supabase/.env.local — never logs its
// contents, never accepts credentials via CLI args (shell history risk).
//
// Values are parsed correctly regardless of quoting/special characters and
// with CRLF stripped (dotenv handles both). Each script must declare which
// subset of fields it actually needs via `requireEnv([...])` — don't
// validate fields a given script doesn't use (a script that only needs the
// CLI-auth pair, for example, shouldn't be blocked by an unrelated field
// still being a placeholder).
import { config } from 'dotenv';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import fs from 'node:fs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const envPath = path.resolve(__dirname, '../../supabase/.env.local');

if (!fs.existsSync(envPath)) {
  console.error(
    `Missing ${envPath}\n` +
    `Copy supabase/.env.local.example to supabase/.env.local and fill in the ` +
    `SECRET values (SUPABASE_DB_URL password, SUPABASE_DB_PASSWORD, ` +
    `SUPABASE_SERVICE_ROLE_KEY, SUPABASE_ACCESS_TOKEN).`
  );
  process.exit(1);
}

const parsed = config({ path: envPath }).parsed ?? {};

const PLACEHOLDER_MARKERS = [
  'YOUR_DB_PASSWORD',
  'YOUR_SERVICE_ROLE_KEY',
  'YOUR_ACCESS_TOKEN',
];

function isPlaceholder(value) {
  return PLACEHOLDER_MARKERS.some((marker) => value.includes(marker));
}

export const env = {
  SUPABASE_URL: parsed.SUPABASE_URL,
  SUPABASE_ANON_KEY: parsed.SUPABASE_ANON_KEY,
  SUPABASE_DB_URL: parsed.SUPABASE_DB_URL,
  SUPABASE_DB_PASSWORD: parsed.SUPABASE_DB_PASSWORD,
  SUPABASE_SERVICE_ROLE_KEY: parsed.SUPABASE_SERVICE_ROLE_KEY,
  SUPABASE_ACCESS_TOKEN: parsed.SUPABASE_ACCESS_TOKEN,
};

/// Validates only the fields this particular script actually needs.
/// Exits with a clear message (naming just the missing/placeholder fields
/// that matter here) if any are absent or still placeholder text.
export function requireEnv(keys) {
  const missing = keys.filter((k) => !env[k]);
  if (missing.length > 0) {
    console.error(`Missing required env vars in supabase/.env.local: ${missing.join(', ')}`);
    process.exit(1);
  }
  const stillPlaceholder = keys.filter((k) => isPlaceholder(env[k]));
  if (stillPlaceholder.length > 0) {
    console.error(
      `supabase/.env.local still has placeholder values for: ${stillPlaceholder.join(', ')}\n` +
      `Fill in the real secrets before running this script.`
    );
    process.exit(1);
  }
}
