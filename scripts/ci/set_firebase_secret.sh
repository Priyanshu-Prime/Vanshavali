#!/usr/bin/env bash
# Stores a Firebase service-account JSON as the FIREBASE_SERVICE_ACCOUNT Actions
# secret, so release.yml can auto-distribute each release to the village-testers
# group. Run once with the path to the downloaded JSON key.
#
#   bash scripts/ci/set_firebase_secret.sh /path/to/service-account.json
#
# Get the JSON from: Firebase Console > Project settings > Service accounts >
# Generate new private key. The account needs the "Firebase App Distribution
# Admin" role (add it in Google Cloud Console > IAM if needed).
set -euo pipefail
export PATH="$PATH:/c/Program Files/GitHub CLI"
command -v gh >/dev/null || { echo "!! gh not found"; exit 1; }
REPO="Priyanshu-Prime/Vanshavali"

SA_JSON="${1:-}"
[ -n "$SA_JSON" ] && [ -f "$SA_JSON" ] || { echo "Usage: $0 /path/to/service-account.json"; exit 1; }
# sanity: must look like a service-account JSON
grep -q '"type": *"service_account"' "$SA_JSON" || { echo "!! that file doesn't look like a service-account JSON"; exit 1; }

gh secret set FIREBASE_SERVICE_ACCOUNT --repo "$REPO" < "$SA_JSON"
echo "FIREBASE_SERVICE_ACCOUNT set. Repo secrets now:"
gh secret list --repo "$REPO"
