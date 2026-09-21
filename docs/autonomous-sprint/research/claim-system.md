# Research: duplicate-detection → claim-request (F-I)

Status: RESEARCHED (2026-09-22). Reuse-heavy. Only NEW thing = detection RPC + thin UI.
Claim reuses `claim_profile` (001) + extended `merge_requests` (009). Auth trail = activity_log (010).

## Framing
Existing `claim_profile*` is invite-authorized (trusted, instant). This flow is claimer-initiated
with NO invite (found via matching) → REQUIRES a human approval step, else claim-jacking. That
approval step is the whole reason a "claim request" exists vs. calling claim_profile directly.

## Migration numbering plan (RESOLVED — avoids the 015 collisions across reports)
- **015** = pg_trgm + 6 GIN indexes + DROP idx_family_members_names + ping() RPC  (infra foundation)
- **016** = avatar_url column + avatars bucket + 4 storage policies  (profile-pic)
- **017** = find_duplicate_candidates + merge_requests extension + request_claim/approve/reject  (this)
017 reuses the indexes from 015 (all `IF NOT EXISTS`), so no duplication.

## 1. Matching — find_duplicate_candidates(...) SECURITY DEFINER STABLE, grant authenticated
Weighted score (0-1), pg_trgm similarity, GREATEST(en,gu) per name field:
- own full name 0.40 · father name 0.20 · mother name 0.15 · village 0.10 (1.0 exact/0.5 partial)
  · dob 0.10 (1.0 exact / 0.6 ±1yr / −0.5 if differ >2yr) · gender 0.05 (HARD-EXCLUDE on mismatch).
Thresholds (naive heuristic, calibrate on real data): ≥0.72 strongly recommend (pre-select);
0.45–0.72 "possible, is this same person?"; <0.45 ignore. Parent names derivable from add-relative
context (child→anchor is father/mother; sibling→anchor's parents). Returns sub-scores + auth_user_id
(claimed vs unclaimed).

## 2. UX — two fire points, one bilingual bottom sheet
- profile_form_screen._saveProfile (~L166, after invite branch, before create) — onboarding self.
- add_family_member_screen._saveMember (~L626, the create-new else branch, when NOT _linkExisting).
Sheet "Is this the same person?" [◻/◯ symbol · name en/gu · village · b.year · parents].
- "Yes": unclaimed + onboarding → claim request (approval). unclaimed + add-relative → route into the
  EXISTING link-existing path (_selectedExistingMember + _applyRelationLink), immediate, no approval.
  claimed by someone else → merge/claim request, never auto.
- "No, create new" → insert as today.

## 3. Claim requests — extend merge_requests (least new schema)
Add `kind text default 'auto_flag' check in (auto_flag,claim_request)` + `target_profile_id uuid`.
Add a SELECT policy (approver = claimed ±1 relative of target via can_edit_family_member; admin fallback).
RPCs: request_claim(target) [validates target unclaimed + caller profile-less], approve_claim_request(id)
[re-checks kinship, sets family_members.auth_user_id = requester, status resolved], reject_claim_request(id).
Inbox surface = home badge + "Requests" list querying merge_requests where caller is eligible approver.
**OWNER DECISION (ambiguous):** overloading merge_requests with 2 workflows is a "one table two meanings"
smell — if they'll diverge, use a separate claim_requests table. Default = generalize. Flag noted.

## 4. Guards
Never auto-merge/claim. Approver ≠ requester. claim_profile's one-profile-per-user unique index (006)
holds. Gender hard-exclude + DOB penalty cut false positives. Rate-limit deferred (trusted village).

## 5. Key DRAFT SQL (for the 017 implementation agent — apply in SQL editor)
find_duplicate_candidates: LEFT JOIN self for father/mother names; hard gender gate in WHERE
(gender null-or-equal); scored CTE with the weights above; WHERE score>=0.45 ORDER BY score DESC LIMIT.
merge_requests: ADD COLUMN kind, target_profile_id. request_claim/approve_claim_request/reject as
plpgsql SECURITY DEFINER (bodies in the R-claim report — re-derive from the rubric; validate
target unclaimed, caller profile-less, approver kinship). New Dart wrappers near flagDuplicateForMerge
(supabase_service.dart:588): findDuplicateCandidates, requestClaim, approveClaimRequest, pendingClaimRequests.
Full draft SQL captured in session transcript (R-claim report) — regenerate faithfully at build time.

## 6. Phased plan
1. Migration 017: find_duplicate_candidates (+ reuse 015 indexes). SQL self-test: known dup ≥0.72,
   gender-mismatch excluded. 2. UI detection (both fire points; "No"=create, "Yes"=link-existing for
   unclaimed relatives) — zero new claim schema, pure reuse. l10n via l10n-strings. 3. Claim-request
   wiring (merge_requests extension + RPCs + inbox + badge) — auth-sensitive, do last, run verify + e2e.
   4. Tests + docs (dup-sheet widget test, l10n parity, SQL self-check) + graphify update.
