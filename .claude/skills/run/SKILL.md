---
name: run
description: Use when asked to run, launch, or screenshot the Vanshavali Flutter app, or to manually confirm a change works on a device/emulator. Project-specific launch skill for this Flutter + Supabase mobile app (Android/iOS only, no web/desktop target).
---

# Running Vanshavali

Mobile-only Flutter app (Android/iOS). There is no meaningful web/desktop target even
though `web/`, `windows/`, `linux/`, `macos/` scaffolding exists in the repo — ignore them.

## Prerequisites

1. Confirm a device or emulator is attached: `flutter devices` (or `adb devices`).
   If none is connected, say so explicitly rather than claiming the app was verified —
   this project has repeatedly had install/verification steps skipped because no
   device was connected (see `docs/claude_handoff/08_verification_log.md`).
2. `flutter pub get` if `pubspec.yaml` changed since the last run.
3. If any `.arb` file under `lib/l10n/` changed, run `flutter gen-l10n` first
   (see the `l10n-strings` skill) — generated code must be current before building.

## Launch

Preferred (hot reload, live logs):
```
flutter run
```

Fallback used previously in this project when `flutter run` wasn't viable:
```
flutter build apk --debug
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```
Note: this fallback requires manually opening the app after install; it does not
give hot reload or console logs.

## Config to be aware of

- Supabase URL/anon key: `lib/config/app_config.dart`.
- Magic-link deep link scheme: `vanshavali://auth/callback` — login via email magic
  link requires the device to actually receive that email and open the link, so
  full login-flow testing needs real network + email access, not just a simulator.

## Golden path to exercise after launching

Walk these in order; they are the flows most recently touched and most likely to
regress (see `docs/claude_handoff/04_current_risks.md` and `05_next_steps.md`):

1. **Login** — send a magic link. Confirm the app *stays on the login screen* and
   shows a snackbar/toast (it must NOT jump to a full-screen spinner — that bug was
   previously caused by `AuthProvider` status going to `loading`).
2. **Profile** — create/edit own bilingual profile.
3. **Family tree** — open the tree with siblings toggled both on and off. Confirm a
   node's children stay positioned under that node and don't drift toward the
   canvas center when sibling rows widen the layout.
4. **Add relation** — try adding a second father/mother/spouse to the same member
   and confirm it's blocked (one-to-one guard). Add a child/sibling and confirm
   multiple entries are allowed (not one-to-one).
5. **Spouse-child prompt** — add a spouse to a member who already has children and
   confirm the app prompts to link those children to the new spouse.
6. **Invite/claim** — generate an invite code from an existing placeholder profile,
   then use it during sign-up on a second account and confirm the profile is claimed
   (`auth_user_id` gets set, not a duplicate row created).

If you can't drive a real device, say explicitly which of these you could not verify.
