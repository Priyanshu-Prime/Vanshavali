# Vanshavali E2E Test Scenarios — the steering document

This is **your control surface** for the automated end-to-end rig. Each
in-scope row here becomes a real test that drives the actual app on an emulator
against a real local Supabase backend (see `integration_test/` and
`scripts/e2e/`). To change what gets tested, edit this file:

- Mark a row `[ ] in scope` → I write/keep the test for it.
- Mark a row `~ out of scope` → I skip it (with a one-line reason).
- Add a new row in plain language → I turn it into a test.

Status legend: `TODO` (not yet automated) · `AUTOMATED` (test exists & runs) ·
`MANUAL` (can't be automated locally — human check) · `SKIP` (de-scoped).

---

## 1. Auth
| # | Scenario | Scope | Status |
|---|----------|-------|--------|
| 1.1 | Fresh signup with email+password creates a session and lands on profile-creation | in | TODO |
| 1.2 | Signing up with an already-registered email is rejected with the "already exists" message (no duplicate profile) | in | TODO |
| 1.3 | Password login for an existing account reaches Home | in | TODO |
| 1.4 | Wrong password shows a friendly error, stays on login | in | TODO |
| 1.5 | Magic-link sign-in: request link, read it from the local mail capture, follow it, reach the app | in | TODO |
| 1.6 | Password reset: request, read link from mail capture, set new password, log in with it | in | TODO |
| 1.7 | Real magic-link email deliverability on the hosted project | out | MANUAL — no real inbox in the rig |

## 2. Invite & Claim
| # | Scenario | Scope | Status |
|---|----------|-------|--------|
| 2.1 | Signup + valid invite code claims the placeholder, no second password prompt, lands on Home as that person | in | ⚠ BLOCKED — test written (flows/signup_claim_test.dart) but SKIPPED: exposed an intermittent app bug — claimProfileByCode's post-claim step throws "Null check operator used on a null value" (swallowed at auth_provider.dart:524), so the client shows claim-FAILED even though the server claim succeeded. Fix the crash, then un-skip. |
| 2.2 | Claiming from the profile-completion screen (not just signup) works | in | TODO |
| 2.3 | Invalid/unknown invite code falls through to manual profile creation, no crash | in | TODO |
| 2.4 | An invite code is single-use — a second claim of the same code fails cleanly | in | ⚠ BLOCKED — same skipped test / same claimProfileByCode crash as 2.1. |
| 2.5 | A user who already has a profile trying to claim another is flagged for merge, shown the reassuring message (not a raw error) | in | TODO |
| 2.6 | Invite-code preview shows the placeholder's name before claiming | in | TODO |

## 3. Profile
| # | Scenario | Scope | Status |
|---|----------|-------|--------|
| 3.1 | Create profile with required fields, lands on Home showing that name | in | TODO |
| 3.2 | Edit own profile, changes persist after reload | in | AUTOMATED (flows/edit_profile_persist_test.dart) |
| 3.3 | Profile-creation screen has a working sign-out escape hatch (no dead-end) | in | TODO |
| 3.4 | Gujarati auto-translation fills the Gujarati name field | out | MANUAL — depends on external translate API |

## 4. Family & Tree
| # | Scenario | Scope | Status |
|---|----------|-------|--------|
| 4.1 | Add a father/mother/child/spouse/sibling and see them linked | in | PARTIAL — child add+link+ego covered (flows/relations_and_ego_test.dart); father/mother/spouse/sibling via UI still TODO |
| 4.2 | Relationship chips are readable in both selected and unselected states | in | TODO |
| 4.3 | Tapping a node re-centers the ego network on that person | in | TODO |
| 4.4 | Pedigree view shows grandparents once the ancestor chain loads | in | TODO |
| 4.5 | Home dashboard shows my own family after exploring the tree (no drift) | in | TODO |
| 4.6 | One-to-one relation guards (no duplicate father, ancestry-cycle block) | in | PARTIAL — 30 unit tests (relation_guards_test.dart) + ancestry-cycle via real DB resolver (flows/relations_and_ego_test.dart); UI-level guard firing still TODO |
| 4.7 | Edit authorization: only own profile + direct unclaimed relatives editable; grandparent/unrelated/claimed-others blocked (migration 010) | in | AUTOMATED (flows/edit_authorization_test.dart) |

## 5. Localization
| # | Scenario | Scope | Status |
|---|----------|-------|--------|
| 5.1 | Language toggle on first onboarding screen switches EN↔GU immediately | in | AUTOMATED (smoke_test.dart — toggle renders; switch interaction TODO) |
| 5.2 | Every user-facing string has both EN and GU (key parity) | in | TODO |

## 6. Offline / Reliability
| # | Scenario | Scope | Status |
|---|----------|-------|--------|
| 6.1 | With the backend unreachable, an existing user still reaches Home from cache (no forced re-profile) | in | TODO |
| 6.2 | Edits made offline sync when back online | in | TODO |
| 6.3 | Real rural-network flakiness (partial timeouts) | out | MANUAL — approximated by 6.1, not fully reproducible locally |

## 7. Deep links
| # | Scenario | Scope | Status |
|---|----------|-------|--------|
| 7.1 | `vanshavali://auth/callback` deep link is handled without crashing | in | TODO |
| 7.2 | Deferred deep link after Play Store install | out | MANUAL — no store in alpha |

---

## Notes / divergences from production to be aware of
- The local stack mirrors `supabase/config.toml` (email confirmation OFF —
  matches the production toggle). If production auth settings change, mirror
  them here so tests stay representative.
- Auth users are created by the tests themselves; only unclaimed placeholder
  profiles are seeded (`supabase/seed.sql`).
