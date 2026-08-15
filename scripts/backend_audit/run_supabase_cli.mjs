// Runs the Supabase CLI (via `npx supabase@latest`) with credentials from
// supabase/.env.local correctly injected as child-process environment
// variables — never via shell `source`/eval.
//
// Why this exists: `source supabase/.env.local` (a plain bash re-parse of
// the file) is unsafe for arbitrary secret values — it re-interprets the
// file as shell script, so a password containing a backtick or `$(...)`
// gets partially executed as a command instead of treated as a literal
// string, silently corrupting the value. The file was also created with
// Windows CRLF line endings, adding an invisible trailing \r to every
// value when read naively. Both bugs were hit for real in this project —
// see docs/claude_handoff — and cost a false "wrong password" diagnosis
// before the actual cause (a parsing bug, not a wrong credential) was
// found. `dotenv` parses `KEY=value` correctly regardless of quoting/
// special characters and strips CRLF; Node's `child_process.spawn` sets
// env vars directly with no shell re-interpretation of their content.
// Together these make secret values byte-for-byte safe end to end.
//
// Usage: node run_supabase_cli.mjs <supabase-cli-args...>
// Example: node run_supabase_cli.mjs migration list

import { spawn } from 'node:child_process';
import { env, requireEnv } from './_env.mjs';

requireEnv(['SUPABASE_ACCESS_TOKEN', 'SUPABASE_DB_PASSWORD']);

const args = process.argv.slice(2);
if (args.length === 0) {
  console.error('Usage: node run_supabase_cli.mjs <supabase-cli-args...>');
  process.exit(1);
}

const child = spawn('npx', ['--yes', 'supabase@latest', ...args], {
  stdio: 'inherit',
  shell: true, // needed to resolve `npx` on Windows; args themselves are
               // passed as a real argv array below them, not interpolated
               // into a shell string, so this doesn't reintroduce the
               // metacharacter risk described above.
  env: {
    ...process.env,
    SUPABASE_ACCESS_TOKEN: env.SUPABASE_ACCESS_TOKEN,
    SUPABASE_DB_PASSWORD: env.SUPABASE_DB_PASSWORD,
  },
});

child.on('exit', (code) => {
  process.exit(code ?? 1);
});
