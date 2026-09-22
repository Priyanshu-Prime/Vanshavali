# Graph Report - vanshavali  (2026-09-22)

## Corpus Check
- 154 files · ~120,819 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 59 file(s) not represented in the graph (top: (none) 10, .xcconfig 8, .xml 7)

## Summary
- 2320 nodes · 2850 edges · 108 communities (79 shown, 29 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 18 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `339b4f4a`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- app_localizations.dart
- app_localizations_gu.dart
- app_localizations_en.dart
- family_tree_screen.dart
- add_family_member_screen.dart
- local_storage_service.dart
- common_widgets.dart
- supabase_service.dart
- onboarding_screen.dart
- family_provider.dart
- gujarat_places_service.dart
- family_member.dart
- auth_provider.dart
- GeneratedPluginRegistrant.swift
- deep_link_service.dart
- package:flutter_test/flutter_test.dart
- AuthProvider
- profile_form_screen.dart
- my_application.cc
- app_theme.dart
- member_detail_screen.dart
- package:vanshavali/models/family_member.dart
- harness.dart
- main.dart
- settings_provider.dart
- gujarat_places_service_test.dart
- signup_screen.dart
- gujarati_edit_sheet.dart
- family_tree_screen_rebuild_test.dart
- WhatsApp Invite Deep-Link Flow — Shared Contract (v1)
- Win32Window
- directory_screen.dart
- home_screen.dart
- win32_window.cpp
- Research: infra / hardening (tasks 1-3, 11-13, 17-20)
- login_screen.dart
- StatelessWidget
- _env.mjs
- set_password_screen.dart
- relations_and_ego_test.dart
- scan_invite_code_screen.dart
- package.json
- rls_behavior_test.mjs
- utils.cpp
- package:flutter/material.dart
- supabase_service_auth_test.dart
- invite_code_parser.dart
- _fix_env_mixup.mjs
- full_tree_graph_test.dart
- flutter_window.h
- MessageHandler
- user_preferences.dart
- manifest.json
- Vanshavali E2E Test Scenarios — the steering document
- app_spacing.dart
- MessageHandler
- windows/flutter/generated_plugin_registrant.cc
- _fix_db_url_to_pooler.mjs
- Point
- error_reporting_service.dart
- Research: duplicate-detection → claim-request (F-I)
- AppLocalizations
- Vanshavali E2E test rig
- FamilyMember
- MockGoTrueClient
- Backend audit tooling
- Git hooks
- app/build.gradle.kts
- MainActivity.kt
- TreeNodeContent
- Vanshavali
- set_firebase_secret.sh
- set_signing_secrets.sh
- setup_automerge.sh
- c_users_priya_asus_laptop_music_appdev_vanshavali_ios_runner_generatedpluginregistrant_h
- _PedigreeConnectorPainter
- pre-push
- LaunchImage.imageset/README.md
- _FamilyTreeEdgeRenderer
- distribute_alpha.sh
- fire_invite_intent.sh
- run_e2e.sh
- start_emulator.sh
- bool?
- String?
- app_config.dart
- Research findings appended by agents
- Vanshavali Autonomous Improvement Sprint — Progress Tracker
- edit_authorization_test.dart
- Backup & restore (Vanshavali, Supabase free tier)
- Research: node profile-pic upload (F-A, #14 compress, #15 limit)
- _GraphViewHost
- _InviteSheet
- village_picker_field.dart
- State
- @visibleForTesting
- load.js
- deep_link_service_test.dart
- Size
- _OtherParentPicker
- plugin_registry
- transliteration_service_test.dart
- invite_code_parser_test.dart
- LocalizationsExt
- BilingualTextField
- backup.sh

## God Nodes (most connected - your core abstractions)
1. `AuthProvider` - 51 edges
2. `FamilyProvider` - 33 edges
3. `SettingsProvider` - 29 edges
4. `Win32Window` - 24 edges
5. `MessageHandler` - 12 edges
6. `FamilyMember` - 11 edges
7. `Vanshavali Autonomous Improvement Sprint — Progress Tracker` - 10 edges
8. `FlutterWindow` - 10 edges
9. `WhatsApp Invite Deep-Link Flow — Shared Contract (v1)` - 10 edges
10. `Create` - 10 edges

## Surprising Connections (you probably didn't know these)
- `Win32Window::Win32Window()` --calls--> `Destroy`  [INFERRED]
  windows/runner/win32_window.cpp → windows/runner/win32_window.h
- `wWinMain()` --calls--> `CreateAndAttachConsole()`  [INFERRED]
  windows/runner/main.cpp → windows/runner/utils.cpp
- `OnCreate` --calls--> `RegisterPlugins()`  [INFERRED]
  windows/runner/flutter_window.h → windows/flutter/generated_plugin_registrant.cc
- `build` --references--> `AuthProvider`  [EXTRACTED]
  lib/main.dart → lib/providers/auth_provider.dart
- `_sendMagicLink` --references--> `AuthProvider`  [EXTRACTED]
  lib/screens/auth/login_screen.dart → lib/providers/auth_provider.dart

## Import Cycles
- None detected.

## Communities (108 total, 29 thin omitted)

### Community 0 - "app_localizations.dart"
Cohesion: 0.01
Nodes (264): app_localizations_en.dart, app_localizations_gu.dart, class, aboutApp, acceptInvite, add, addChild, addFamilyMember (+256 more)

### Community 1 - "app_localizations_gu.dart"
Cohesion: 0.01
Nodes (251): app_localizations.dart, aboutApp, acceptInvite, add, addChild, addFamilyMember, addFather, addingAdditionalSpouse (+243 more)

### Community 2 - "app_localizations_en.dart"
Cohesion: 0.01
Nodes (251): aboutApp, acceptInvite, add, addChild, addFamilyMember, addFather, addingAdditionalSpouse, additionalDetails (+243 more)

### Community 3 - "family_tree_screen.dart"
Cohesion: 0.02
Nodes (107): Algorithm, GlobalKey, Graph, GraphViewController?, ahnentafel, algorithm, _buildDefaultView, buildFullTreeData (+99 more)

### Community 4 - "add_family_member_screen.dart"
Cohesion: 0.03
Nodes (67): any, _applyRelationLink, _askForOtherParent, _askLinkChildrenToSpouse, _askParentsMarried, _askSiblingShare, blockedOneToOneRelation, build (+59 more)

### Community 5 - "local_storage_service.dart"
Cohesion: 0.04
Nodes (52): _addAdjacency, addPendingSync, clearAll, clearFamilyMembers, clearPendingSyncs, clearSpouseLinks, connectivityStream, deleteFamilyMember (+44 more)

### Community 6 - "common_widgets.dart"
Cohesion: 0.05
Nodes (42): AppLocalizations get, EdgeInsetsGeometry, AppWidgets, build, children, color, createState, duration (+34 more)

### Community 7 - "supabase_service.dart"
Cohesion: 0.04
Nodes (46): dart:math, addSpouseLink, authStateChanges, canEditMember, claimProfile, claimProfileByCode, client, completeSignInFromUrl (+38 more)

### Community 8 - "onboarding_screen.dart"
Cohesion: 0.08
Nodes (24): Color?, build, _buildPage, color, _completeOnboarding, createState, currentCode, _currentPage (+16 more)

### Community 9 - "family_provider.dart"
Cohesion: 0.05
Nodes (37): _ancestorChain, _ancestorChainForId, _centerMember, clearError, clearSearch, createFamilyMember, deleteFamilyMember, _egoNetwork (+29 more)

### Community 10 - "gujarat_places_service.dart"
Cohesion: 0.05
Nodes (39): Client, dart:convert, dart:developer, _assetPath, _byDistrict, code, district, _districts (+31 more)

### Community 11 - "family_member.dart"
Cohesion: 0.05
Nodes (40): hashCode, operator, read, typeId, write, int get, authUserId, copyWith (+32 more)

### Community 12 - "auth_provider.dart"
Cohesion: 0.05
Nodes (39): AuthStatus get, acknowledgeMergeConflict, _authenticatedWithPassword, AuthStatus, _authSubscription, claimProfile, claimProfileByCode, clearError (+31 more)

### Community 13 - "GeneratedPluginRegistrant.swift"
Cohesion: 0.06
Nodes (27): Any, app_links, Cocoa, connectivity_plus, Flutter, FlutterAppDelegate, FlutterMacOS, FlutterPluginRegistry (+19 more)

### Community 14 - "deep_link_service.dart"
Cohesion: 0.11
Nodes (18): dart:async, _appLinks, buildInviteUrl, DeepLinkService, dispose, generateInviteText, initialize, isAuthCallback (+10 more)

### Community 15 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.10
Nodes (24): harness.dart, main, main, _father, main, _self, main, main (+16 more)

### Community 16 - "AuthProvider"
Cohesion: 0.11
Nodes (33): ChangeNotifier, _handleDeepLink, _routeToSignupWithCode, AuthProvider, FamilyProvider, SettingsProvider, build, build (+25 more)

### Community 17 - "profile_form_screen.dart"
Cohesion: 0.06
Nodes (31): _cityController, createState, dispose, _educationController, existingMember, _firstNameDebounce, _firstNameEnController, _firstNameGuController (+23 more)

### Community 18 - "my_application.cc"
Cohesion: 0.07
Nodes (28): file_selector_plugin, FlPluginRegistry, flutter_linux, FlView, GApplication, gboolean, gchar, gdkx (+20 more)

### Community 19 - "app_theme.dart"
Cohesion: 0.07
Nodes (28): app_spacing.dart, AppTheme, darkBackground, darkSurface, darkText, darkTextSecondary, darkTheme, errorColor (+20 more)

### Community 20 - "member_detail_screen.dart"
Cohesion: 0.10
Nodes (20): add_family_member_screen.dart, FamilyMember get, _canEdit, children, createState, _ensureInviteCode, icon, _inviteCode (+12 more)

### Community 21 - "package:vanshavali/models/family_member.dart"
Cohesion: 0.10
Nodes (19): package:graphview/GraphView.dart, package:vanshavali/models/family_member.dart, package:vanshavali/providers/family_provider.dart, package:vanshavali/screens/family/family_tree_screen.dart, String? motherId,
  String, main, firstName, gender (+11 more)

### Community 22 - "harness.dart"
Cohesion: 0.07
Nodes (26): Duration, bootApp, clearAll, end, ensureVisible, enterInField, enterText, field (+18 more)

### Community 23 - "main.dart"
Cohesion: 0.09
Nodes (23): ../l10n/app_localizations.dart, build, _checkOnboarding, _completeAuthFromUrl, createState, dispose, _initDeepLinks, initState (+15 more)

### Community 24 - "settings_provider.dart"
Cohesion: 0.08
Nodes (23): bool get, DateTime?, DateTime? get, fullSync, _hasPendingSyncs, isDarkMode, _isOffline, _lastSyncTime (+15 more)

### Community 25 - "gujarat_places_service_test.dart"
Cohesion: 0.50
Nodes (3): package:vanshavali/services/gujarat_places_service.dart, _fixture, main

### Community 26 - "signup_screen.dart"
Cohesion: 0.10
Nodes (21): build, _confirmPasswordController, createState, dispose, _emailController, _formKey, initState, _inviteCodeController (+13 more)

### Community 27 - "gujarati_edit_sheet.dart"
Cohesion: 0.10
Nodes (21): build, _candidates, _choose, createState, currentGujarati, _debounce, dispose, englishText (+13 more)

### Community 28 - "family_tree_screen_rebuild_test.dart"
Cohesion: 0.10
Nodes (20): GraphView, InteractiveViewer, authProvider, child1, child2, _currentScale, familyProvider, father (+12 more)

### Community 29 - "WhatsApp Invite Deep-Link Flow — Shared Contract (v1)"
Cohesion: 0.10
Nodes (18): App custom scheme (what the page's "Open in app" button fires), Automated (headless, real local-Supabase backend), CI/CD requirements, End-to-end test checklist, Full manual journey (the parts no tooling can drive), Hosting, Landing page behavior (bilingual EN/GU, low-tech-user UX), Logging (understand failures) (+10 more)

### Community 30 - "Win32Window"
Cohesion: 0.16
Nodes (18): FlutterViewController, RECT, unique_ptr, FlutterWindow, flutter_controller_, OnCreate, OnDestroy, project_ (+10 more)

### Community 31 - "directory_screen.dart"
Cohesion: 0.13
Nodes (16): ../config/app_config.dart, ../family/member_detail_screen.dart, createState, dispose, _ensureLoaded, _loadedForId, _query, _searchController (+8 more)

### Community 32 - "home_screen.dart"
Cohesion: 0.11
Nodes (18): ../directory/directory_screen.dart, ../family/add_family_member_screen.dart, ../family/family_tree_screen.dart, IconData, int?, count, createState, _currentIndex (+10 more)

### Community 33 - "win32_window.cpp"
Cohesion: 0.16
Nodes (15): dwmapi, wchar_t, Scale(), Create, Destroy, SetQuitOnClose, Show, UpdateTheme (+7 more)

### Community 34 - "Research: infra / hardening (tasks 1-3, 11-13, 17-20)"
Cohesion: 0.18
Nodes (10): #11/#12 — the ONE real gap: search. DRAFT migration 015 (indexes only), #13 — pagination. SCOPING CORRECTION for F-E, #17 — keep-alive + uptime (URGENT: 7-day auto-pause), #18 — error_logs → Slack (error_logs already exists, 008), #19 — load test, #1/#3 — rate limiting, #20 — backups (no PITR on free tier), Already indexed — DO NOT re-create (+2 more)

### Community 35 - "login_screen.dart"
Cohesion: 0.12
Nodes (16): FormState, createState, dispose, _emailController, _formKey, _isLoading, LoginScreen, _LoginScreenState (+8 more)

### Community 36 - "StatelessWidget"
Cohesion: 0.12
Nodes (16): _LineageBanner, _MarriageConnector, _PersonBox, _SiblingsBadge, _UnitWidget, _ZoomButton, _ZoomControls, _AddRelationTile (+8 more)

### Community 37 - "_env.mjs"
Cohesion: 0.17
Nodes (13): ref_node_child_process, ref_node_path, pg, __dirname, env, envPath, isPlaceholder(), PLACEHOLDER_MARKERS (+5 more)

### Community 38 - "set_password_screen.dart"
Cohesion: 0.15
Nodes (13): build, _confirmPasswordController, createState, dispose, _formKey, _isLoading, _obscureConfirmPassword, _obscurePassword (+5 more)

### Community 39 - "relations_and_ego_test.dart"
Cohesion: 0.13
Nodes (13): claimSelf, _father, _grandfather, main, _newChild, _ramesh, _self, package:vanshavali/screens/family/add_family_member_screen.dart (+5 more)

### Community 40 - "scan_invite_code_screen.dart"
Cohesion: 0.12
Nodes (16): build, buttonLabel, _controller, createState, dispose, _handled, message, _onDetect (+8 more)

### Community 41 - "package.json"
Cohesion: 0.14
Nodes (13): dotenv, @supabase/supabase-js, dependencies, dotenv, pg, @supabase/supabase-js, description, name (+5 more)

### Community 42 - "rls_behavior_test.mjs"
Cohesion: 0.24
Nodes (12): RFC-2606, actorClientFor(), admin, createTestUser(), finding(), findings, insertMember(), main() (+4 more)

### Community 43 - "utils.cpp"
Cohesion: 0.19
Nodes (12): flutter_windows, _In_, _In_opt_, io, iostream, stdio, wWinMain(), string (+4 more)

### Community 44 - "package:flutter/material.dart"
Cohesion: 0.10
Nodes (22): main, package:flutter_localizations/flutter_localizations.dart, package:flutter/material.dart, package:provider/provider.dart, package:vanshavali/l10n/app_localizations.dart, package:vanshavali/providers/auth_provider.dart, package:vanshavali/providers/settings_provider.dart, package:vanshavali/screens/auth/signup_screen.dart (+14 more)

### Community 45 - "supabase_service_auth_test.dart"
Cohesion: 0.18
Nodes (11): AuthApiException, AuthException, Fake, package:mocktail/mocktail.dart, package:supabase_flutter/supabase_flutter.dart, FakeUserAttributes, main, mockAuth (+3 more)

### Community 46 - "invite_code_parser.dart"
Cohesion: 0.17
Nodes (11): code, _codeFromUrl, fromUrl, _normalizeCandidate, normalized, null, parseInviteCode, _sixCharCode (+3 more)

### Community 47 - "_fix_env_mixup.mjs"
Cohesion: 0.18
Nodes (9): __dirname, exLines, exPath, isRealValue(), localLines, localPath, movedKeys, PLACEHOLDER_MARKERS (+1 more)

### Community 48 - "full_tree_graph_test.dart"
Cohesion: 0.17
Nodes (11): dad, gp1, kid, _m, main, maternalAunt, me, members (+3 more)

### Community 49 - "flutter_window.h"
Cohesion: 0.27
Nodes (7): dart_project, flutter_view_controller, functional, memory, string, vector, windows

### Community 50 - "MessageHandler"
Cohesion: 0.18
Nodes (10): generated_plugin_registrant, optional, DartProject, HWND, LPARAM, LRESULT, UINT, WPARAM (+2 more)

### Community 51 - "user_preferences.dart"
Cohesion: 0.18
Nodes (10): copyWith, currentMemberId, currentUserId, fromJson, hasCompletedOnboarding, isDarkMode, lastSyncTime, locale (+2 more)

### Community 52 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 53 - "Vanshavali E2E Test Scenarios — the steering document"
Cohesion: 0.20
Nodes (9): 1. Auth, 2. Invite & Claim, 3. Profile, 4. Family & Tree, 5. Localization, 6. Offline / Reliability, 7. Deep links, Notes / divergences from production to be aware of (+1 more)

### Community 54 - "app_spacing.dart"
Cohesion: 0.20
Nodes (9): AppSpacing, lg, md, minTapTarget, sm, xl, xs, xxl (+1 more)

### Community 55 - "MessageHandler"
Cohesion: 0.36
Nodes (10): HWND, LPARAM, LRESULT, UINT, WPARAM, EnableFullDpiSupportIfAvailable(), GetHandle, GetThisFromHandle (+2 more)

### Community 56 - "windows/flutter/generated_plugin_registrant.cc"
Cohesion: 0.25
Nodes (7): app_links_plugin_c_api, connectivity_plus_windows_plugin, file_selector_windows, PluginRegistry, share_plus_windows_plugin_c_api, url_launcher_windows, RegisterPlugins()

### Community 57 - "_fix_db_url_to_pooler.mjs"
Cohesion: 0.22
Nodes (8): ref_node_fs, ref_node_url, __dirname, idx, lines, localPath, password, pwLine

### Community 58 - "Point"
Cohesion: 0.50
Nodes (3): Point, x, y

### Community 59 - "error_reporting_service.dart"
Cohesion: 0.29
Nodes (6): ErrorReportingService, initialize, _report, reportCaught, package:flutter/foundation.dart, supabase_service.dart

### Community 60 - "Research: duplicate-detection → claim-request (F-I)"
Cohesion: 0.20
Nodes (9): 1. Matching — find_duplicate_candidates(...) SECURITY DEFINER STABLE, grant authenticated, 2. UX — two fire points, one bilingual bottom sheet, 3. Claim requests — extend merge_requests (least new schema), 4. Guards, 5. Key DRAFT SQL (for the 017 implementation agent — apply in SQL editor), 6. Phased plan, Framing, Migration numbering plan (RESOLVED — avoids the 015 collisions across reports) (+1 more)

### Community 61 - "AppLocalizations"
Cohesion: 0.33
Nodes (6): AppLocalizations, _AppLocalizationsDelegate, AppLocalizationsEn, AppLocalizationsGu, of, LocalizationsDelegate

### Community 62 - "Vanshavali E2E test rig"
Cohesion: 0.33
Nodes (5): Each run, Layout, One-time setup, Vanshavali E2E test rig, What stays manual

### Community 63 - "FamilyMember"
Cohesion: 0.40
Nodes (5): @HiveType, FamilyMemberAdapter, HiveObject, FamilyMember, TypeAdapter

### Community 64 - "MockGoTrueClient"
Cohesion: 0.40
Nodes (5): GoTrueClient, Mock, SupabaseClient, MockGoTrueClient, MockSupabaseClient

### Community 65 - "Backend audit tooling"
Cohesion: 0.40
Nodes (4): Backend audit tooling, Running, Setup (one-time), What's here

### Community 66 - "Git hooks"
Cohesion: 0.50
Nodes (3): Git hooks, One-time setup, What's here

### Community 69 - "TreeNodeContent"
Cohesion: 0.67
Nodes (3): SiblingsBadgeContent, TreeNodeContent, TreeUnitContent

### Community 87 - "app_config.dart"
Cohesion: 0.11
Nodes (18): AppConfig, appName, appVersion, cacheDuration, deepLinkHost, deepLinkScheme, familyMembersBox, pageSize (+10 more)

### Community 88 - "Research findings appended by agents"
Cohesion: 0.14
Nodes (13): Backups, Backups (no PITR on free tier), Carried over from earlier (not part of this sprint but still open), Load test params (when you want it run), Migrations to apply in the SQL editor (loop writes the files; you run them) — apply IN ORDER 015→016→017, Owner-Action Items — Vanshavali Sprint, Pending (fill in / do when convenient), Prod auth rate limits (+5 more)

### Community 89 - "Vanshavali Autonomous Improvement Sprint — Progress Tracker"
Cohesion: 0.18
Nodes (10): A. Infra / hardening requirements, B. App-specific features, Feature branches (integrate near the end onto a release branch, then main → release), Ground rules (do not violate), Integration state (2026-09-22 i9): all green, 151 tests, Iteration log, Migration numbering plan (locked, avoids collisions), Research agents dispatched (iteration 1, 2026-09-22) (+2 more)

### Community 90 - "edit_authorization_test.dart"
Cohesion: 0.33
Nodes (5): _father, _grandfather, main, _self, _unrelated

### Community 91 - "Backup & restore (Vanshavali, Supabase free tier)"
Cohesion: 0.33
Nodes (5): Backup, Backup & restore (Vanshavali, Supabase free tier), Owner action, Restore (into a fresh / recovery project), Restore-test drill (do once to prove backups work)

### Community 92 - "Research: node profile-pic upload (F-A, #14 compress, #15 limit)"
Cohesion: 0.33
Nodes (5): Decisions (minimal / ponytail), DRAFT migration (assign real number at build time — coordinate with R-infra's index migration to avoid a 015 collision), Implementation order, Owner-action (fallback only — appended to NEEDS-OWNER-ACTION), Research: node profile-pic upload (F-A, #14 compress, #15 limit)

### Community 95 - "village_picker_field.dart"
Cohesion: 0.10
Nodes (20): common_widgets.dart, build, createState, dispose, _district, initState, _list, _loading (+12 more)

### Community 96 - "State"
Cohesion: 0.20
Nodes (14): AppNavigator, _AppNavigatorState, DirectoryScreen, _DirectoryScreenState, AddFamilyMemberScreen, _AddFamilyMemberScreenState, FamilyTreeScreen, _FamilyTreeScreenState (+6 more)

### Community 97 - "@visibleForTesting"
Cohesion: 0.40
Nodes (5): @visibleForTesting, debugSetAncestorChainForTesting, debugSetFullTreeForTesting, debugSetNetworkForTesting, debugNotifyForTesting

### Community 98 - "load.js"
Cohesion: 0.40
Nodes (4): ref_k6, anonHeaders, authHeaders, options

### Community 100 - "Size"
Cohesion: 0.50
Nodes (3): Size, height, width

## Knowledge Gaps
- **1716 isolated node(s):** `Supabase dashboard`, `Third-party signups (all have free tiers)`, `Backups`, `Carried over from earlier (not part of this sprint but still open)`, `🔴 URGENT — free-tier 7-day auto-pause (do this first)` (+1711 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 1899 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **29 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `FamilyMember` connect `FamilyMember` to `family_tree_screen.dart`, `add_family_member_screen.dart`, `local_storage_service.dart`, `family_provider.dart`, `family_member.dart`, `auth_provider.dart`, `profile_form_screen.dart`, `member_detail_screen.dart`?**
  _High betweenness centrality (0.031) - this node is a cross-community bridge._
- **Why does `AuthProvider` connect `AuthProvider` to `State`, `home_screen.dart`, `login_screen.dart`, `add_family_member_screen.dart`, `family_tree_screen.dart`, `set_password_screen.dart`, `auth_provider.dart`, `profile_form_screen.dart`, `member_detail_screen.dart`, `main.dart`, `signup_screen.dart`, `directory_screen.dart`?**
  _High betweenness centrality (0.024) - this node is a cross-community bridge._
- **Why does `FamilyProvider` connect `AuthProvider` to `State`, `home_screen.dart`, `family_tree_screen.dart`, `add_family_member_screen.dart`, `family_provider.dart`, `profile_form_screen.dart`, `member_detail_screen.dart`, `directory_screen.dart`?**
  _High betweenness centrality (0.010) - this node is a cross-community bridge._
- **What connects `Supabase dashboard`, `Third-party signups (all have free tiers)`, `Backups` to the rest of the system?**
  _1716 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `app_localizations.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.007547169811320755 - nodes in this community are weakly interconnected._
- **Should `app_localizations_gu.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.007936507936507936 - nodes in this community are weakly interconnected._
- **Should `app_localizations_en.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.007936507936507936 - nodes in this community are weakly interconnected._