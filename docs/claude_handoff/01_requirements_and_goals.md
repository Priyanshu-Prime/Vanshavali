# Requirements and Goals

## Primary product goal
Build a village-scale lineage app that lets users create profiles, connect family relationships, and view an ego-centric family tree.

## Hard constraints
- Zero-cost development and initial deployment.
- Use Supabase Free Tier.
- Flutter mobile app only for Android and iOS.
- English and Gujarati must both be supported.
- UI must remain extremely simple for low-tech users.
- Tree fetching must stay ego-centric and not load the entire village.

## Core user flows
- Login with email magic link.
- Sign up with email and password.
- Create a bilingual profile.
- View and edit own profile.
- Add parents, children, spouse, and siblings.
- Invite and claim placeholder profiles.
- Navigate the family tree by tapping nodes.

## Product decisions already made
- Supabase Auth is the auth layer.
- Magic links are the preferred low-cost sign-in path.
- Deep links are used for invite flow, but the project also needs invite-code fallback for uninstalled or unreachable-link cases.
- The tree uses a custom layout rather than loading full-village data.
- Gujarati names may be translated automatically or edited manually.

## UI and UX rules
- Large touch targets.
- High contrast.
- Minimal steps.
- Genealogical symbols should remain recognizable.
- Buttons and dialogs should be obvious to non-technical users.

## Development order originally requested
1. Supabase client and Auth.
2. Profile creation form.
3. Dashboard.
4. Family-link logic.
5. Visualization.

## Additional constraints learned during implementation
- One-to-one relations such as father, mother, and spouse must be guarded at both UI level and save level.
- Child and sibling relations remain multi-entry relationships.
- The spouse flow should still ask about children when a spouse is added.
