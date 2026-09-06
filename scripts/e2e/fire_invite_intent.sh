#!/usr/bin/env bash
# Fires the invite deep-link intent at the installed app on a running Android
# emulator/device — the ONE half of the WhatsApp invite journey that a headless
# widget test can't cover: a real OS VIEW intent hitting the manifest
# intent-filter (scheme=vanshavali host=invite) → app_links → main._handleDeepLink
# → SignupScreen with the code prefilled. See docs/whatsapp_invite_flow.md.
#
# Prereq: the app must already be INSTALLED on the device (build+install it, or
# run the E2E rig first). The emulator is where you'd normally have it.
#
# Usage:
#   scripts/e2e/fire_invite_intent.sh [CODE]     # default CODE = TEST01
#
# Then watch the breadcrumbs the app emits (debugPrint -> logcat tag "flutter"):
#   adb logcat -s flutter | grep -iE 'deeplink|invite|claim'
# Expected sequence: link received -> invite code parsed -> routed to signup ->
# (after you submit) claim attempt result: success.

set -euo pipefail
cd "$(dirname "$0")/../.."

CODE="${1:-TEST01}"
PKG="com.vanshavali.app"

DEVICE="$(flutter devices --machine 2>/dev/null \
  | grep -oE 'emulator-[0-9]+' | head -1 || true)"
if [[ -z "${DEVICE}" ]]; then
  echo "!! No running emulator found. Start one with scripts/e2e/start_emulator.sh" >&2
  exit 1
fi

URI="vanshavali://invite?code=${CODE}"
echo "==> Firing ${URI} at ${DEVICE} (package ${PKG})"
adb -s "${DEVICE}" shell am start \
  -a android.intent.action.VIEW \
  -c android.intent.category.BROWSABLE \
  -d "${URI}" \
  "${PKG}"

cat <<EOF

==> Now verify on the device:
    - The app opens on the Sign Up screen with the 6-character code field
      pre-filled with "${CODE}".
    - Watch the log breadcrumbs:
        adb -s ${DEVICE} logcat -s flutter | grep -iE 'deeplink|invite|claim'
      Expect: link received -> invite code parsed -> routed to signup, then
      "claim attempt result: success" once you complete signup.
EOF
