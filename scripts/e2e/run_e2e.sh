#!/usr/bin/env bash
# End-to-end test runner for Vanshavali.
#
# Drives the REAL app on an Android emulator against a REAL local Supabase
# stack (Postgres + Auth + RLS + your actual migrations). This is what catches
# the backend-seam bugs the mock-based unit tests under test/ cannot see.
#
# Prereqs (one-time, see scripts/e2e/README.md):
#   - Docker Desktop running
#   - An Android emulator booted (scripts/e2e/start_emulator.sh)
#   - `npx supabase start` has been run at least once
#
# Usage:
#   scripts/e2e/run_e2e.sh [integration_test/target_test.dart]
# With no argument, runs the whole integration_test/ suite.

set -euo pipefail
cd "$(dirname "$0")/../.."

TARGET="${1:-integration_test/}"

echo "==> Ensuring local Supabase is up..."
if ! npx --yes supabase status >/dev/null 2>&1; then
  echo "    Starting Supabase (first run pulls images, may take a few minutes)..."
  npx --yes supabase start
fi

echo "==> Resetting local DB (re-applies migrations + seed.sql)..."
# `db reset` recreates the Postgres container, which intermittently fails on
# this Windows/Docker host with a transient "error running container" — retry a
# couple of times before giving up, since a re-run almost always succeeds.
reset_ok=false
for attempt in 1 2 3; do
  if npx --yes supabase db reset; then reset_ok=true; break; fi
  echo "    db reset attempt ${attempt} failed; retrying..." >&2
  sleep 5
done
if [[ "${reset_ok}" != "true" ]]; then
  echo "!! db reset failed after 3 attempts." >&2
  exit 1
fi

echo "==> Reading local Supabase credentials..."
STATUS_ENV="$(npx --yes supabase status -o env)"
# Lines look like: API_URL="http://127.0.0.1:54321"  ANON_KEY="eyJ..."
API_URL="$(printf '%s\n' "$STATUS_ENV" | sed -n 's/^API_URL="\(.*\)"$/\1/p')"
ANON_KEY="$(printf '%s\n' "$STATUS_ENV" | sed -n 's/^ANON_KEY="\(.*\)"$/\1/p')"

if [[ -z "${API_URL}" || -z "${ANON_KEY}" ]]; then
  echo "!! Could not read API_URL/ANON_KEY from 'supabase status'." >&2
  printf '%s\n' "$STATUS_ENV" >&2
  exit 1
fi

# The app runs inside the Android emulator, where the host machine's localhost
# is reachable as 10.0.2.2 — not 127.0.0.1.
EMU_URL="${API_URL/127.0.0.1/10.0.2.2}"
EMU_URL="${EMU_URL/localhost/10.0.2.2}"

echo "    Host API:     ${API_URL}"
echo "    Emulator API: ${EMU_URL}"

echo "==> Selecting a running Android emulator..."
# Match the emulator serial regardless of JSON spacing (flutter emits
# `"id": "emulator-5554"`). `|| true` keeps `set -e`/pipefail from aborting the
# script on a no-match; the emptiness check below reports it properly instead.
DEVICE="$(flutter devices --machine 2>/dev/null \
  | grep -oE 'emulator-[0-9]+' | head -1 || true)"
if [[ -z "${DEVICE}" ]]; then
  echo "!! No running emulator found. Start one with scripts/e2e/start_emulator.sh" >&2
  exit 1
fi
echo "    Using device: ${DEVICE}"

echo "==> Running integration tests: ${TARGET}"
flutter test "${TARGET}" \
  -d "${DEVICE}" \
  --dart-define=SUPABASE_URL="${EMU_URL}" \
  --dart-define=SUPABASE_ANON_KEY="${ANON_KEY}"
