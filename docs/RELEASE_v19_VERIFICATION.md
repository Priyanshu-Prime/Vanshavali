# Release v0.1.0-alpha.2+19 — Owner feedback + full regression (2026-10-10)

Branch `fix/plus18-ux` (plus `ui/polish` from the UI/UX agent, merged before release).
Tested on the owner's phone (Motorola Edge 50 Fusion, Android 16) over adb, release-signed
build installed over the existing app, against **prod**, with throwaway
`test+{e,f,g}1010@example.com` accounts and "*Echodemo/Foxdemo*" names (deleted afterwards).

## Owner requests (all done)
| Request | Result |
|---|---|
| Own photo on Home card | ✅ (also on relation rows; tree photos 36→56px) |
| Photo not visible after reopening Edit Profile | 🐞 root cause: photo uploaded but only linked on Save → now saved on pick ✅ verified (back-out keeps it) |
| Crop / rotate when picking a photo | ✅ image_cropper: square crop, zoom, 90° + fine rotate |
| Woman's village = father's village (maika) | ✅ hint under Village for women (EN/GU); father/sibling prefill own village, child prefills father's (husband's) village + surname, mother/spouse blank |
| Same sort on both Directory tabs | ✅ surname, then first name |
| My-family village chips misaligned | ✅ row sizes to the chips |
| Requests badge label | ✅ "Requests" / "વિનંતીઓ" next to the icon |
| Hide empty Additional Details | ✅ only shown when education/occupation set |
| Forgot password | ✅ already existed; error messages fixed (rate-limit, wrong password, SMTP failure) |
| Cleanup | ✅ 3 stale worktrees, 36 local + 5 remote merged branches, CRLF-only stash removed; kept fix/phone-otp, chore/dead-code-cleanup |

## Regression — passed on-device
Read-only on owner's account: Directory tabs/filter/search/pagination, tree long-press menu,
"Explore Lata's family" + Back to mine, dark mode (Home + tree), Settings version.
Test accounts: sign-up → crop/rotate → profile (female hint) → Home photo; edit photo + Back;
add father (prefill), mother (blank + hint), child w/o husband (blank), spouse, child
(husband's village + "Who is the Father?" prompt → correct parents in DB), sibling (auto-linked
to father); invite share text; invite deep link → code prefilled → claim; reused code rejected
("Invalid or already claimed"); claimed profile not editable, unclaimed editable; edit
occupation persists and shows immediately; delete relative; wrong password message; QR scanner.

## Bugs found during the run → fixed
1. Filled Home cards opened "Add Family Member"; sibling cards did nothing.
2. Profile page showed the pre-edit copy after editing.
3. A woman's child got her surname instead of her husband's.
4. Add Family Member: Save silent when the error was off-screen; stale red errors.
5. Wrong password reset the login screen (email lost, no error) — LoginScreen was unmounted
   by the full-screen spinner during sign-in.
6. Home showed a relative's family under your name after returning from their profile.
7. SMTP failure (500) reported as "No internet connection".

## Not verified / open
- **Email (magic link, forgot password): BLOCKED** — Supabase returns 500 "Error sending
  recovery email" after the Brevo SMTP change; owner to check SMTP login/key/sender.
- `supabase/.env.local` service-role key + access token are rejected (rotated?).
- Invite links use `?code=` which Supabase also treats as a PKCE code → harmless logged
  "Code verifier could not be found" on every invite open.
- Local builds need Gradle temporarily capped at `-Xmx2G` (8GB laptop).
