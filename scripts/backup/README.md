# Backup & restore (Vanshavali, Supabase free tier)

Free tier has **no PITR** — manual logical dumps are the only recovery path. Run
a backup weekly and keep the file off Supabase.

## Backup
```bash
export SUPABASE_DB_URL="postgresql://postgres.<ref>:<pw>@aws-0-<region>.pooler.supabase.com:5432/postgres"
./backup.sh
```
Use the **Session pooler** string (IPv4) from Dashboard → Settings → Database.
The direct `db.<ref>.supabase.co` host is IPv6-only on free tier.

Alternative via the Supabase CLI (already used in this repo):
```bash
supabase db dump --linked -f vanshavali_backup.sql            # schema + data
supabase db dump --linked --data-only -f vanshavali_data.sql  # data only
```

## Restore (into a fresh / recovery project)
```bash
pg_restore --clean --if-exists \
  -d "postgresql://postgres.<ref>:<pw>@aws-0-<region>.pooler.supabase.com:5432/postgres" \
  backups/vanshavali_YYYYMMDD_HHMM.dump
```

## Restore-test drill (do once to prove backups work)
1. Take a dump with `backup.sh`.
2. Create a throwaway Supabase project (or a local `supabase start` stack).
3. `pg_restore` the dump into it.
4. Sanity-check row counts: `select count(*) from family_members;` matches source.
5. Delete the throwaway project.

## Owner action
The connection string + DB password are yours to supply (Dashboard → Settings →
Database). Optionally schedule `backup.sh` weekly (cron, or a GitHub Action with
`SUPABASE_DB_URL` as an encrypted secret). See NEEDS-OWNER-ACTION.md.
