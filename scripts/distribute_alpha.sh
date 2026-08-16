#!/usr/bin/env bash
# Build a release APK and push it to the Firebase App Distribution
# "village-testers" group. Requires the Firebase CLI (`npm install -g
# firebase-tools`) and being logged in (`firebase login`) as an account with
# access to the vanshavali-52e45 Firebase project.
#
# Usage: scripts/distribute_alpha.sh "Release notes go here"

set -euo pipefail

PROJECT_ID="vanshavali-52e45"
APP_ID="1:975879058030:android:27cfa11a36aba40607ec7f"
GROUP="village-testers"
NOTES="${1:-New alpha build.}"

echo "Building release APK..."
flutter build apk --release

echo "Uploading to Firebase App Distribution..."
firebase appdistribution:distribute \
  "build/app/outputs/flutter-apk/app-release.apk" \
  --app "$APP_ID" \
  --groups "$GROUP" \
  --release-notes "$NOTES" \
  --project "$PROJECT_ID"

echo "Done. Manage testers at:"
echo "  https://console.firebase.google.com/project/$PROJECT_ID/appdistribution/app/android:com.vanshavali.app/testers-groups"
