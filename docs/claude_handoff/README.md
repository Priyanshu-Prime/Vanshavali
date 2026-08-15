# Claude Code Handoff

Start here. This folder is a durable handoff for the next coding agent working on Vanshavali.

## What this project is
Vanshavali is a Flutter mobile app for a village community to track ancestry and lineage. It uses Supabase for backend/auth and supports English and Gujarati.

## What matters most
- Mobile-only app for Android and iOS.
- Zero-cost / free-tier-first approach.
- Easy for low-tech users.
- Bilingual UI in English and Gujarati.
- Tree must be ego-centric, not full-village.
- Invite and claim flow must work without relying on a reachable custom link.

## Read these files in order
1. `docs/claude_handoff/00_repo_map.md`
2. `docs/claude_handoff/01_requirements_and_goals.md`
3. `docs/claude_handoff/02_work_completed.md`
4. `docs/claude_handoff/03_recent_requests_and_commands.md`
5. `docs/claude_handoff/04_current_risks.md`
6. `docs/claude_handoff/05_next_steps.md`
7. `docs/claude_handoff/06_supabase_and_data_model.md`
8. `docs/claude_handoff/07_file_touchpoints.md`
9. `docs/claude_handoff/08_verification_log.md`

## Current status snapshot
- Tree visualization exists and has been updated multiple times.
- Invite code claim flow exists.
- Magic-link loading behavior has been corrected.
- Duplicate one-to-one relationship guards were added.
- Spouse linking now prompts for children to link.

## Important caution
Some parts of the code were changed late in the session. Before continuing larger work, re-run analysis and test the full flows for tree layout, login, and relation linking.
