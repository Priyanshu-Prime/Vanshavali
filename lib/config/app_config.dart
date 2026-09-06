/// Supabase Configuration
class SupabaseConfig {
  // URL/key default to the hosted alpha project, but can be overridden at
  // build time with --dart-define so the E2E rig can point the real app at a
  // local Supabase stack without editing this file. A production build with
  // no --dart-define is byte-for-byte unchanged. From the Android emulator,
  // localhost is reachable as 10.0.2.2, so the local override is typically
  //   --dart-define=SUPABASE_URL=http://10.0.2.2:54321
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://lsmualpdhtpdpdhfmdmj.supabase.co',
  );

  // New-format Supabase publishable key (replaces the old anon JWT format;
  // supabase_flutter accepts either interchangeably as the client API key).
  // The local stack prints its own anon key on `supabase start`; pass it via
  // --dart-define=SUPABASE_ANON_KEY=... for E2E runs.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_sihPTWjfbjQeqvY1OqI8Uw_lnfcMbye',
  );
  
  // Deep link scheme for the app
  static const String deepLinkScheme = 'vanshavali';
  
  // Deep link host
  static const String deepLinkHost = 'auth';
  
  // Redirect URL for magic link authentication
  static String get redirectUrl => '$deepLinkScheme://$deepLinkHost/callback';
}

/// App Configuration
class AppConfig {
  static const String appName = 'Vanshavali';
  static const String appVersion = '1.0.0';
  
  // Hive box names for local storage
  static const String familyMembersBox = 'family_members';
  static const String userPrefsBox = 'user_preferences';
  static const String pendingSyncBox = 'pending_sync';
  static const String spouseLinksBox = 'spouse_links';
  
  // Cache duration
  static const Duration cacheDuration = Duration(hours: 24);
  
  // Pagination
  static const int pageSize = 20;
}
