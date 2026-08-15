# Repository Map

## Root folders
- `.dart_tool/` - Flutter/Dart tool state. Generated.
- `.flutter-plugins-dependencies` - generated plugin metadata.
- `.gitignore` - ignore rules.
- `.idea/` - IDE metadata.
- `.metadata` - Flutter project metadata.
- `analysis_options.yaml` - analyzer/lint rules.
- `android/` - Android native project.
- `assets/` - static assets, currently images.
- `build/` - generated build artifacts.
- `CLAUDE.md` - original project brief and architecture guidance.
- `ios/` - iOS native project.
- `l10n.yaml` - Flutter localization generation config.
- `lib/` - Flutter application source.
- `linux/` - Linux desktop scaffold.
- `macos/` - macOS desktop scaffold.
- `pubspec.lock` - resolved package versions.
- `pubspec.yaml` - dependencies, assets, app metadata.
- `README.md` - generic starter README, not yet project-specific.
- `scripts/` - currently empty.
- `supabase/` - database migrations.
- `test/` - widget tests.
- `vanshavali.iml` - IntelliJ project file.
- `web/` - web scaffold.
- `windows/` - Windows desktop scaffold.

## `lib/` structure
- `lib/main.dart` - app bootstrap, providers, locale setup, deep links, auth routing.
- `lib/config/` - app configuration, Supabase config.
- `lib/l10n/` - arb source files and generated localization classes.
- `lib/models/` - family member model and user preferences model.
- `lib/providers/` - auth, family, and settings state management.
- `lib/screens/` - auth, family, home, onboarding, profile, settings screens.
- `lib/services/` - Supabase, local storage, deep link, translation services.
- `lib/theme/` - theme definitions.
- `lib/widgets/` - shared widgets and Gujarati editing UI.

## `supabase/` structure
- `supabase/migrations/001_initial_schema.sql` - base schema, RLS, and RPCs.
- `supabase/migrations/002_invite_code.sql` - invite code and claim-by-code migration.
- `supabase/migrations/003_multiple_spouses.sql` - adds `spouse_relationships`
  many-to-many table, drops `spouse_id` column, updates `get_ego_network`. Exists
  on disk but **not yet applied** to the live Supabase project — see
  `06_supabase_and_data_model.md`.

## Test area
- `test/widget_test.dart` - default Flutter widget test scaffold.

## Scripts area
- `scripts/` is empty right now. If future automation is needed, this is the obvious place.
