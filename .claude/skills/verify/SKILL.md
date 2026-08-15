---
name: verify
description: Project verify skill for Vanshavali. Use before considering any nontrivial change to lib/ or supabase/migrations/ complete — runs static checks plus the manual flow checklist this project actually needs (tree layout, auth, relation guards, invites) because most of the risk here is not caught by flutter analyze alone.
---

# Verifying Vanshavali changes

This app has no automated coverage for its highest-risk logic (custom tree layout,
relationship guards, auth-status routing). `flutter analyze` passing is necessary
but not sufficient — treat it as step one, not the finish line.

## 1. Static checks (always run these)

```
flutter analyze
```
Must be clean (or unchanged from baseline — don't let a change introduce new
warnings/errors). If `test/` has relevant tests:
```
flutter test
```

## 2. Build sanity

```
flutter build apk --debug
```
Confirms the change compiles for a real target, not just the analyzer.

## 3. Manual flow verification (device required)

Do this whenever a change touches any of: `lib/main.dart`, `lib/providers/*`,
`lib/screens/auth/*`, `lib/screens/family/*`, `lib/services/supabase_service.dart`,
or `supabase/migrations/*`. See the `run` skill for how to launch.

Pick the specific flows relevant to the change from this list — don't skip the ones
the diff actually touches:

- **Auth/login routing** (`lib/main.dart`, `auth_provider.dart`): magic-link send
  keeps the user on the login screen with a snackbar; the app only shows the
  full-screen loading state during an actual session check, never just because a
  link was sent.
- **Tree layout** (`family_tree_screen.dart`): check with siblings shown AND hidden.
  Children must stay under their parent node, not drift toward canvas center.
  Tapping a node re-centers the tree on it.
- **Relationship guards** (`add_family_member_screen.dart`, `family_provider.dart`):
  father/mother are one-to-one — adding a second one must be blocked, and the check
  must re-fetch the latest member record before saving (stale local state has caused
  duplicate relations before). Spouse, child, and sibling are multi-entry — spouse
  supports remarriage via `spouse_relationships`; the only spouse guard is against
  inserting the exact same pair twice.
- **Spouse-child linking**: adding a spouse to a member with existing children
  prompts to link those children to the new spouse.
- **Invite/claim** (`supabase_service.dart`, `002_invite_code.sql`): a generated
  invite code claims the correct placeholder row and never creates a duplicate.

## 4. Data-model sync check

If a migration under `supabase/migrations/` changed, confirm
`lib/models/family_member.dart` (and the Hive schema, if applicable) was updated to
match — schema and Dart model drifting apart is a known failure mode here. See the
`supabase-migration` skill.

## 5. Report honestly

State plainly which of the above you actually ran vs. skipped (e.g. "no device
connected, manual flows unverified"). Don't claim a flow works if you only read the
code — this project has been burned by changes that passed `flutter analyze` but
broke the tree layout or the login spinner behavior at runtime.
