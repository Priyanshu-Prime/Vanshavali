class UserPreferences {
  final String? locale;
  final bool isDarkMode;
  final String? lastSyncTime;
  final bool hasCompletedOnboarding;
  final String? currentUserId;
  final String? currentMemberId;

  UserPreferences({
    this.locale,
    this.isDarkMode = false,
    this.lastSyncTime,
    this.hasCompletedOnboarding = false,
    this.currentUserId,
    this.currentMemberId,
  });

  Map<String, dynamic> toJson() {
    return {
      'locale': locale,
      'is_dark_mode': isDarkMode,
      'last_sync_time': lastSyncTime,
      'has_completed_onboarding': hasCompletedOnboarding,
      'current_user_id': currentUserId,
      'current_member_id': currentMemberId,
    };
  }

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      locale: json['locale'] as String?,
      isDarkMode: json['is_dark_mode'] as bool? ?? false,
      lastSyncTime: json['last_sync_time'] as String?,
      hasCompletedOnboarding: json['has_completed_onboarding'] as bool? ?? false,
      currentUserId: json['current_user_id'] as String?,
      currentMemberId: json['current_member_id'] as String?,
    );
  }

  UserPreferences copyWith({
    String? locale,
    bool? isDarkMode,
    String? lastSyncTime,
    bool? hasCompletedOnboarding,
    String? currentUserId,
    String? currentMemberId,
  }) {
    return UserPreferences(
      locale: locale ?? this.locale,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      hasCompletedOnboarding: hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      currentUserId: currentUserId ?? this.currentUserId,
      currentMemberId: currentMemberId ?? this.currentMemberId,
    );
  }
}
