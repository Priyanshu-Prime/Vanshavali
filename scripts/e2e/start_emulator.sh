#!/usr/bin/env bash
# Boot the Vanshavali test emulator (creates the AVD on first run).
# Leaves the emulator running in the background; run once before run_e2e.sh.

set -euo pipefail

SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$LOCALAPPDATA/Android/Sdk}}"
AVD_NAME="vanshavali_test"
IMAGE="system-images;android-34;google_apis;x86_64"

AVDMANAGER="$SDK/cmdline-tools/latest/bin/avdmanager.bat"
EMULATOR="$SDK/emulator/emulator.exe"

if [[ ! -f "$EMULATOR" ]]; then
  echo "!! Emulator not installed. Run:" >&2
  echo "   \"$SDK/cmdline-tools/latest/bin/sdkmanager.bat\" \"emulator\" \"$IMAGE\"" >&2
  exit 1
fi

# Create the AVD if it doesn't exist yet.
if ! "$AVDMANAGER" list avd 2>/dev/null | grep -q "Name: $AVD_NAME"; then
  echo "==> Creating AVD '$AVD_NAME'..."
  echo "no" | "$AVDMANAGER" create avd -n "$AVD_NAME" -k "$IMAGE" -d "pixel_6" --force
fi

echo "==> Booting emulator '$AVD_NAME' (no window, fast boot)..."
"$EMULATOR" -avd "$AVD_NAME" -no-snapshot-save -no-boot-anim -gpu swiftshader_indirect &

echo "==> Waiting for device to come online..."
"$SDK/platform-tools/adb.exe" wait-for-device
# Wait until the boot completes, not just device online.
until [[ "$("$SDK/platform-tools/adb.exe" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]]; do
  sleep 2
done
echo "==> Emulator ready."
