# Vanshavali UI/UX audit (branch `ui/polish`)

Source: 54 on-device screenshots (Motorola, 1080x2400) in `D:/vansh_work/ui_screens/`, plus a read of `lib/screens/**`, `lib/widgets/**` and `lib/theme/**`.
Severity: **High** = broken, unreadable or misleading. **Med** = inconsistent or looks unfinished. **Low** = polish.
Status: **Fixed** = done on `ui/polish`. **Rec** = recommended, not done (needs owner sign-off or a device check).

## Root causes (several screens had the same few problems)

| # | Problem | Sev | Status |
|---|---|---|---|
| R1 | `ColorScheme` only set about 10 roles. Unset roles fell back to other colours: `outline` became black and `onPrimaryContainer` became `onPrimary`. As a result, empty-relation icons on Home were pure black (s16, s25, c4) and the dark-mode sibling initial was dark on dark green (r4). | High | Fixed: every role a screen reads is now set, in both themes |
| R2 | Light and dark themes were two copy-pasted 200-line blocks that drifted apart (tab bar, chips, inputs). | Med | Fixed: one `_build(Brightness)` makes both |
| R3 | `FilledButton` had no theme, so it rendered as an M3 pill next to 12dp-rounded Elevated/Outlined buttons (s24 *Check again*, s26 *Approve* next to *Reject*, s27 *View family tree*). | Med | Fixed: `filledButtonTheme` and `segmentedButtonTheme` share the 12dp control shape |
| R4 | Each screen drew its own avatar: solid green (Home), light green (siblings), amber (relation rows, s28/e1), theme default (Directory, s02/r1). Only some showed photos. | Med | Fixed: one `MemberAvatar` (photo, falling back to the initial) used everywhere |
| R5 | Cards had a 2dp drop shadow that stacked into a heavy, blurry look on long forms (s08–s15, s27). | Low | Fixed: flat cards with a hairline `outlineVariant` border |
| R6 | Status-bar icons were white on the near-white Login/Onboarding background, so they were invisible (s05, r7). | High | Fixed: an app-wide `AnnotatedRegion` (in `main.dart`) gives dark icons on light screens and light icons in dark mode. App bars keep white icons through `AppBarTheme.systemOverlayStyle`. |

## Per screen

### Login / Sign-up (s05, s06, r7)
- Status bar invisible on Login: see R6. Sign-up and Set-password have app bars, so they keep white icons on the bar. **High, Fixed.**
- Sign-up invite card: the title used `titleSmall` while other section titles used `titleLarge`, and it couldn't wrap for Gujarati. **Med, Fixed** (title style matches, wraps).
- The "0/6" counter under the invite code was noise because the hint already says 6 characters. **Low, Fixed.**
- Scan button sat flush against the field. **Low, Fixed** (8dp gap).

### Complete Your Profile / Edit profile (s08–s15, s22, v2–v5, c3)
- Same invite-card issues as Sign-up. **Med, Fixed.**
- "Required" stays red while the user retypes (s14/s15, c8/c9). Existing code already switches to `onUserInteraction` after the first failed submit, so this is the intended behaviour. **Low, no change.**
- Error snackbar floats over the Save button (v2). **Low, Rec**: show the error inline above the button, or give the snackbar a bottom margin.

### Photo crop (c1, c2)
- c1's toolbar was a different, lighter green and the canvas was tinted green. The dark theme passed its lighter `primary` into `image_cropper`. **Med, Fixed**: brand green toolbar and black canvas in both themes.

### Village picker (s10)
- Clean. The close button overlapping a mic-like icon looks like the keyboard's overlay, not the app. **Low, no change.**

### Home (s01, s04, s16, s25, c4, c5, r4)
- Empty relation icons were black while filled ones were green (R1). **Med, Fixed**: empty = grey `outline`, filled = the person's avatar.
- Dark mode: sibling initial unreadable (R1). **High, Fixed.**
- Profile, sibling and relation cards now show photos (R4). **Med, Fixed.**
- "My Family" (`headlineSmall`) and "Siblings" (`titleLarge`) headings didn't match, and the grid gap was off the spacing scale. **Low, Fixed.**
- FAB was white text on #FF6F00, about 2.8:1 contrast. **Med, Fixed**: accent changed to Orange 900 #E65100 (4.5:1).

### Family Tree (s03, s17, s18, s30, r2, r5, v1, v6)
- Floating "Viewing X's family" banner covered the top row's connector lines (r2). **Med, Fixed**: the banner now sits above the canvas.
- View-mode bar was shrink-wrapped, leaving background-coloured strips at both edges (s03, r5). **Low, Fixed**: full width with a hairline divider.
- Connector lines were pure black (white in dark), which looked harsh. They now use the `outline` grey (4.6:1 on white). **Low, Fixed** (goldens regenerated and checked).
- Lines striking through nodes (s30) was already fixed on this branch (4c21c3d, opaque node fill).
- Female ovals clipped at the right edge on first paint (s03, r2). **Low, Rec**: fit-to-view or initial-centre tweak. Not changed because it touches layout and goldens.
- Nodes have a large empty lower half and a small photo (s17/s18). **Low, Rec**: a bigger photo or a shorter node. Left alone because node size feeds the layout spacing.

### Directory (s02, r1)
- Initials only, no photos (R4). **Med, Fixed.**
- "92 people" count was tight against the chip row. **Low, Fixed.**

### Member profile (s27–s29, e1)
- Add Father / Mother / Spouse / Child / Sibling were content-width outlined buttons, which made a ragged stack. **Med, Fixed**: full width.
- Short "Additional Details" card rendered as a narrow stub (s27; the empty case was already hidden in b92bb40). **Low, Fixed** at the root: `SectionCard` is always full width.
- Invite card: white text on #4CAF50 (about 2.3:1) in the e1 build. On this branch the card uses `primaryContainer`/`onPrimaryContainer`, which are now explicit (dark green on light green, about 9:1). **High, Fixed via R1.**
- Pill "View family tree" button (R3). **Low, Fixed.**

### Add Family Member (s19–s21, c6–c9, d1, d2)
- "Create New / Link Existing Member" radios were side by side, and the label wrapped to 3 lines. **Med, Fixed**: stacked.
- Spouse gender wasn't preset. **Med, Fixed**: defaults to the opposite of the person (still editable). Changing the relation now resets gender to that relation's default, so child and sibling stay a deliberate pick. Unit-tested in `test/screens/family/default_gender_test.dart`.
- Name and gender fields had no icons, unlike the profile form. **Low, Fixed.**
- Confirm dialog (s21): fine. Dialog shape and typography are now themed.

### "Is this the same person?" sheet (s23)
- Square and circle outline icons looked like unticked checkboxes. **Med, Fixed**: shows the person's avatar.

### Waiting for approval (s24)
- Black hourglass. **Low, Fixed**: brand green.
- Pill vs rounded buttons (R3). **Low, Fixed.**

### Requests (s26)
- The requester email was the boldest line and the name being claimed was smaller. **Med, Fixed**: avatar and profile name lead, requester and date are secondary.
- Pill Approve next to rounded Reject (R3). **Low, Fixed.**
- A raw email is shown as identity. **Rec**: show the requester's name once the backend exposes it (backend change, out of scope).

### Settings (r3, r6)
- Theme row read "Dark Mode / Dark Mode" or "Dark Mode / Light Mode". **Med, Fixed**: subtitle removed (the switch shows the state). The unused `lightMode` string was removed from both ARBs.

## Design system (standardised in `lib/theme/app_theme.dart`)

**Colour roles (light / dark)**

| Role | Light | Dark | Used for |
|---|---|---|---|
| primary | #1B5E20 | #4CAF50 | brand, primary buttons, focus |
| primaryContainer / on | #C8E6C9 / #0D3610 | #1B5E20 / #C8E6C9 | avatars, invite card |
| secondary (accent) | #E65100 | #FFB300 | FAB only |
| secondaryContainer / on | #FFB300 / black | #FFB300 / black | selected chips, segments, banners |
| outline | #757575 | #9E9E9E | empty-state icons, tree lines, chip borders |
| outlineVariant | #E0E0E0 | #3A3A3A | card and input borders, dividers |
| error / errorContainer | #D32F2F / #FFDAD6 | #EF5350 / #5C1A1A | errors |
| Tree nodes | male #1976D2 box, female #D81B60 oval, unclaimed #9E9E9E | same | genealogy symbols (unchanged) |

**Type scale.** Poppins for headings and buttons. Noto Sans for body text (it has Gujarati glyphs).
display 32/28/24 · headline 20/18 · **titleLarge 17 = every section/card heading** · titleMedium 15 · titleSmall 14 · bodyLarge 16 · bodyMedium 14 · bodySmall 13 (secondary colour) · buttons 16 w600.

**Spacing.** `AppSpacing` 4 / 8 / 16 / 24 / 32 / 48. Screen padding 16, gap between cards 16, inside a card 16, related items 8. Minimum tap target 48dp.

**Radii.** Controls (buttons, inputs, chips) 12 · cards and FAB 16 · dialogs and bottom sheets 24 (`AppTheme.radiusControl/Card/Sheet`).

**Elevation.** Cards 0 with a 1px `outlineVariant` border · FAB 3 · zoom buttons 3 · app bar 0 (no scroll tint).

**Components.** Every button type (Elevated, Filled, Outlined, Text, Segmented) is at least 48dp tall with a 12dp radius. Snackbar is floating with a 12dp radius. Avatars always go through `MemberAvatar` (`lib/widgets/common_widgets.dart`).

## Not changed (needs owner sign-off)
1. Accent orange went from #FF6F00 to #E65100 (darker) for contrast. Revert in `AppTheme.secondaryColor` if the brighter orange is wanted.
2. Tree node size and photo size, and clipping at the edges on first paint. These are layout changes that need an on-device check and goldens.
3. Moving the form error snackbar off the Save button.
4. Requester name instead of email on Requests (needs backend data).
5. Login lower half is empty. It could hold a language toggle, but that is a flow change.

None of this has been checked on a device. The constraints rule out building an APK or running an emulator, so check it on the phone before release (Home dark mode, tree banner, crop screen, Login status bar).
