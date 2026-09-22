#!/usr/bin/env bash
# Vanshavali logical backup (Supabase free tier — no PITR, so manual dumps are
# the only recovery path). Run weekly; store the dump OFF Supabase.
#
# Free-tier gotcha: the direct DB host (db.<ref>.supabase.co:5432) is IPv6-only
# without the paid IPv4 add-on. Most home/CI networks are IPv4, so use the
# SESSION POOLER string (…pooler.supabase.com:5432, IPv4). Get it from:
#   Dashboard → Project Settings → Database → Connection string → Session pooler.
#
# Usage:
#   export SUPABASE_DB_URL="postgresql://postgres.<ref>:<pw>@aws-0-<region>.pooler.supabase.com:5432/postgres"
#   ./backup.sh                 # writes vanshavali_YYYYMMDD_HHMM.dump (custom format)
#
# Requires: pg_dump (v15+ to match Supabase's Postgres 17 server; use the
# Supabase CLI's bundled tools or a matching pg_dump if version errors appear).
set -euo pipefail

: "${SUPABASE_DB_URL:?Set SUPABASE_DB_URL to the Session-pooler connection string}"

OUT_DIR="${BACKUP_DIR:-./backups}"
mkdir -p "$OUT_DIR"
STAMP="$(date +%Y%m%d_%H%M)"
OUT="$OUT_DIR/vanshavali_${STAMP}.dump"

echo "[backup] dumping to $OUT (custom format, compressed)…"
# -Fc: custom format → smaller + parallel restore. Excludes roles (not needed
# for a same-project restore); schema + data included.
pg_dump "$SUPABASE_DB_URL" -Fc -f "$OUT"

echo "[backup] done: $(du -h "$OUT" | cut -f1) → $OUT"
echo "[backup] keep this file somewhere OTHER than Supabase (e.g. Drive/local)."
