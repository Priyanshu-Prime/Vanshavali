#!/usr/bin/env bash
# Pushes the Android release-signing material from your LOCAL, gitignored
# android/key.properties + keystore into GitHub Actions secrets, so release.yml
# can build a SIGNED release APK. Run once from the repo root (re-run to rotate).
# Nothing here is committed and no value is printed — only the secret NAMES.
#
# Prereq: `gh auth login` done; run from the repo root.
set -euo pipefail
# gh is installed but may not be on PATH in a fresh shell — add its default location.
export PATH="$PATH:/c/Program Files/GitHub CLI"
command -v gh >/dev/null || { echo "!! gh not found. Install: winget install GitHub.cli"; exit 1; }
REPO="Priyanshu-Prime/Vanshavali"
cd "$(dirname "$0")/../.."

KS="android/upload-keystore.jks"
[ -f "$KS" ] || { echo "!! keystore not found at $KS"; exit 1; }
[ -f android/key.properties ] || { echo "!! android/key.properties missing"; exit 1; }

sp=$(grep -E '^storePassword=' android/key.properties | cut -d= -f2-)
kp=$(grep -E '^keyPassword='   android/key.properties | cut -d= -f2-)
ka=$(grep -E '^keyAlias='      android/key.properties | cut -d= -f2-)

base64 -w0 "$KS" | gh secret set ANDROID_KEYSTORE_BASE64   --repo "$REPO"
printf '%s' "$sp" | gh secret set ANDROID_KEYSTORE_PASSWORD --repo "$REPO"
printf '%s' "$kp" | gh secret set ANDROID_KEY_PASSWORD      --repo "$REPO"
printf '%s' "$ka" | gh secret set ANDROID_KEY_ALIAS         --repo "$REPO"

echo "Signing secrets set. Repo secrets now:"
gh secret list --repo "$REPO"
