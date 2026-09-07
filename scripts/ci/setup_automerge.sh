#!/usr/bin/env bash
# One-time repo governance for "auto-check-and-merge PRs":
#   1. Enables the repo's auto-merge feature.
#   2. Protects `main` so a PR can only merge once the CI checks
#      (analyze-and-test, build-apk) pass.
# Human PR review is NOT required (so a PR set to auto-merge can complete on its
# own), and admins are NOT enforced (you can still push directly in a pinch).
#
# TRADE-OFF: after this, the normal way onto main is a PR. To let a PR merge
# itself once CI is green:  gh pr merge <N> --auto --merge
#
# Run once from the repo root after `gh auth login`.
set -euo pipefail
export PATH="$PATH:/c/Program Files/GitHub CLI"
command -v gh >/dev/null || { echo "!! gh not found"; exit 1; }
REPO="Priyanshu-Prime/Vanshavali"
TMP="$(mktemp -d)"

echo "==> Enabling repo auto-merge..."
gh api -X PATCH "repos/$REPO" -F allow_auto_merge=true --jq '"allow_auto_merge = \(.allow_auto_merge)"'

echo "==> Protecting main (require CI checks)..."
cat > "$TMP/protection.json" <<'JSON'
{
  "required_status_checks": { "strict": false, "contexts": ["analyze-and-test", "build-apk"] },
  "enforce_admins": false,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": false
}
JSON
gh api -X PUT "repos/$REPO/branches/main/protection" --input "$TMP/protection.json" >/dev/null
gh api "repos/$REPO/branches/main/protection" \
  --jq '"Protected. Required checks: \(.required_status_checks.contexts | join(\", \"))"'
rm -rf "$TMP"
echo "Done."
