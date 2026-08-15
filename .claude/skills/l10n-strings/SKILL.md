---
name: l10n-strings
description: Use when adding, changing, or removing any user-facing text in the Vanshavali app. This project mandates bilingual English/Gujarati support via .arb files — every string change must touch both locales and regenerate localization code correctly.
---

# Adding/editing UI strings (English + Gujarati)

Bilingual support is a hard project requirement (see root `CLAUDE.md`), not optional.

## Steps

1. Add the new key to **both** `lib/l10n/app_en.arb` and `lib/l10n/app_gu.arb`. Never
   add a key to only one file — a missing Gujarati string is a shipped bug for this
   audience, not a nice-to-have.
2. If you don't have a confident Gujarati translation, use the project's translation
   service (`lib/services/translation_service.dart`) or ask the user — don't leave a
   key untranslated or duplicate the English text as a placeholder without flagging it.
3. Regenerate: `flutter gen-l10n`. This project's generation is controlled entirely by
   `l10n.yaml` — command-line flags/overrides are ignored, so don't try to pass
   `--arb-dir` etc. on the CLI expecting it to take effect.
4. Never hand-edit generated files under `lib/l10n/app_localizations*.dart` — they're
   regenerated from the `.arb` sources and manual edits will be silently lost.
5. Reference the string via the generated `AppLocalizations` accessor in widgets, not
   a hardcoded string literal.
6. Run `flutter analyze` after regenerating to catch any missing-key or type mismatch
   between the two `.arb` files (mismatched placeholders between `en`/`gu` are a
   common source of generation errors).
