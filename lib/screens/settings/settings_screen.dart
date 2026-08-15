import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/settings_provider.dart';
import '../../config/app_config.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/common_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settingsProvider = context.watch<SettingsProvider>();
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Language Section
          SectionCard(
            title: l10n.language,
            children: [
              RadioGroup<String>(
                groupValue: settingsProvider.locale.languageCode,
                onChanged: (value) {
                  if (value != null) {
                    settingsProvider.setLocale(value);
                  }
                },
                child: Column(
                  children: [
                    RadioListTile<String>(
                      title: Text(l10n.english),
                      value: 'en',
                    ),
                    RadioListTile<String>(
                      title: Text(l10n.gujarati),
                      value: 'gu',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Theme Section
          SectionCard(
            title: l10n.theme,
            children: [
              SwitchListTile(
                title: Text(l10n.darkMode),
                subtitle: Text(
                  settingsProvider.isDarkMode ? l10n.darkMode : l10n.lightMode,
                ),
                value: settingsProvider.isDarkMode,
                onChanged: (value) {
                  settingsProvider.setDarkMode(value);
                },
                secondary: Icon(
                  settingsProvider.isDarkMode
                      ? Icons.dark_mode
                      : Icons.light_mode,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Sync Section
          SectionCard(
            title: l10n.syncData,
            children: [
              ListTile(
                leading: Icon(
                  settingsProvider.isOffline
                      ? Icons.cloud_off
                      : Icons.cloud_done,
                  color: settingsProvider.isOffline
                      ? Colors.orange
                      : Colors.green,
                ),
                title: Text(
                  settingsProvider.isOffline
                      ? l10n.offlineMode
                      : l10n.online,
                ),
                subtitle: settingsProvider.lastSyncTime != null
                    ? Text(l10n.lastSynced(
                        _formatTime(settingsProvider.lastSyncTime!, l10n),
                      ))
                    : null,
              ),
              if (settingsProvider.hasPendingSyncs)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      const Icon(Icons.pending, color: Colors.orange),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          l10n.dataWillSync,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: settingsProvider.isOffline
                          ? null
                          : () => settingsProvider.syncData(),
                      icon: const Icon(Icons.sync),
                      label: Text(l10n.syncData),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: settingsProvider.isOffline
                          ? null
                          : () async {
                              final auth = context.read<AuthProvider>();
                              final family = context.read<FamilyProvider>();
                              try {
                                await settingsProvider.fullSync();
                                await auth.refreshCurrentMember();
                                family.clearSearch();
                                if (auth.currentMember != null) {
                                  await family.loadEgoNetwork(auth.currentMember!.id);
                                }
                                if (context.mounted) {
                                  showAppSnackBar(context, l10n.fullSyncComplete);
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  showAppSnackBar(
                                    context,
                                    friendlyErrorMessage(context, e.toString()),
                                    isError: true,
                                  );
                                }
                              }
                            },
                      icon: const Icon(Icons.cloud_download),
                      label: Text(l10n.fullSync),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // About Section
          SectionCard(
            title: l10n.aboutApp,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(l10n.version),
                trailing: Text(AppConfig.appVersion),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: Text(l10n.privacyPolicy),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(l10n.privacyNotice),
                      content: Text(l10n.privacyNoticeBody),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(l10n.close),
                        ),
                      ],
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(l10n.termsOfService),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showAppSnackBar(context, l10n.featureComingSoon);
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Logout Button
          ElevatedButton.icon(
            onPressed: () async {
              final confirmed = await showConfirmDialog(
                context: context,
                title: l10n.logout,
                message: l10n.confirmLogout,
                isDestructive: true,
              );
              if (confirmed) {
                await authProvider.signOut();
              }
            },
            icon: const Icon(Icons.logout),
            label: Text(l10n.logout),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  String _formatTime(DateTime time, dynamic l10n) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return l10n.justNow;
    } else if (diff.inHours < 1) {
      return l10n.minutesAgo(diff.inMinutes);
    } else if (diff.inDays < 1) {
      return l10n.hoursAgo(diff.inHours);
    } else {
      return l10n.daysAgo(diff.inDays);
    }
  }
}
