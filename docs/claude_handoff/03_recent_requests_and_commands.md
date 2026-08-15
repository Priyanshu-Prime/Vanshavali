# Recent User Requests and Actions

## Recent user requests
- Fix the layout so when siblings are shown, a node's children do not shift to the center of the whole tree.
- Change magic-link behavior so the app stays on the login screen and shows a small toast that the link was sent.
- Restore the flow that asks about children when a spouse is added.
- Produce a full handoff structure for Claude Code with everything needed to continue.

## Important earlier requests from this session
- Make the copy-link and share buttons equal size.
- Explain why a custom invite link was unreachable.
- Add an invite code that can be used during sign-up to claim a profile.
- Prevent duplicate one-to-one family relations.

## Implementation actions already performed
- Added invite-code migration.
- Added inviteCode field to the model and Hive schema.
- Added invite-code generate/claim methods in SupabaseService.
- Added invite-code support in signup and invite UIs.
- Fixed `signInWithMagicLink` so it no longer sets the app to global loading.
- Updated the tree layout for child positioning under the focus node.
- Added stronger duplicate relation guards in the add-family-member flow.
- Added the spouse-child linking prompt after spouse creation.

## Commands and checks already run during the session
- `flutter analyze`
- `flutter build apk --debug`
- `flutter pub add url_launcher share_plus`
- `flutter gen-l10n`
- `adb install -r build\app\outputs\flutter-apk\app-debug.apk`

## Commands and outcomes worth remembering
- Analyze passed after the final code changes.
- APK build completed successfully.
- Device install later failed once because no device/emulator was connected.
- Localization generation was controlled by `l10n.yaml`, so command-line overrides were ignored.
