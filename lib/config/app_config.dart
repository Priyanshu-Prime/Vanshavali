/// Supabase Configuration
class SupabaseConfig {
  static const String supabaseUrl = 'https://lsmualpdhtpdpdhfmdmj.supabase.co';

  // New-format Supabase publishable key (replaces the old anon JWT format;
  // supabase_flutter accepts either interchangeably as the client API key).
  static const String supabaseAnonKey = 'sb_publishable_sihPTWjfbjQeqvY1OqI8Uw_lnfcMbye';
  
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
