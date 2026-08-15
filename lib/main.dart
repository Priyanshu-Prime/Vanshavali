import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'providers/auth_provider.dart';
import 'providers/family_provider.dart';
import 'providers/settings_provider.dart';
import 'services/supabase_service.dart';
import 'services/local_storage_service.dart';
import 'services/deep_link_service.dart';
import 'theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/set_password_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/profile/profile_form_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize local storage
  try {
    await LocalStorageService.initialize();
  } catch (e) {
    debugPrint('Error initializing LocalStorageService: $e');
  }
  
  // Initialize Supabase
  try {
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('Error initializing SupabaseService: $e');
  }

  runApp(const VanshavaliApp());
}

class VanshavaliApp extends StatefulWidget {
  const VanshavaliApp({super.key});

  @override
  State<VanshavaliApp> createState() => _VanshavaliAppState();
}

class _VanshavaliAppState extends State<VanshavaliApp> {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FamilyProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          return MaterialApp(
            title: AppConfig.appName,
            debugShowCheckedModeBanner: false,
            
            // Theme
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: settingsProvider.themeMode,
            
            // Localization
            locale: settingsProvider.locale,
            supportedLocales: const [
              Locale('en'), // English
              Locale('gu'), // Gujarati
            ],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            
            home: const AppNavigator(),
          );
        },
      ),
    );
  }
}

/// Main navigator that handles auth state and deep links
class AppNavigator extends StatefulWidget {
  const AppNavigator({super.key});

  @override
  State<AppNavigator> createState() => _AppNavigatorState();
}

class _AppNavigatorState extends State<AppNavigator> {
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
    _initDeepLinks();
  }

  void _checkOnboarding() {
    _showOnboarding = !LocalStorageService.hasCompletedOnboarding();
  }

  Future<void> _initDeepLinks() async {
    // Handle initial deep link
    final initialUri = await DeepLinkService.initialize();
    if (initialUri != null) {
      _handleDeepLink(initialUri);
    }

    // Listen for subsequent deep links
    DeepLinkService.listen(_handleDeepLink);
  }

  void _handleDeepLink(Uri uri) {
    final authProvider = context.read<AuthProvider>();
    
    // Handle invite links
    final memberId = DeepLinkService.parseInviteLink(uri);
    if (memberId != null) {
      authProvider.setPendingInvite(memberId);
    }
    
    // Handle auth callbacks
    if (DeepLinkService.isAuthCallback(uri)) {
      // Supabase handles this automatically
    }
  }

  @override
  void dispose() {
    DeepLinkService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // Show loading while checking auth state
    if (authProvider.status == AuthStatus.initial ||
        authProvider.status == AuthStatus.loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Show onboarding for first-time users
    if (_showOnboarding) {
      return OnboardingScreen(
        onComplete: () {
          setState(() => _showOnboarding = false);
        },
      );
    }

    // Show login if not authenticated
    if (authProvider.status == AuthStatus.unauthenticated) {
      return const LoginScreen();
    }

    // Show profile form if authenticated but no profile
    if (!authProvider.hasProfile) {
      return const ProfileFormScreen(isCreatingProfile: true);
    }

    // Mandatory, non-dismissible: a magic-link-only account has no password
    // yet. See AuthProvider.hasPasswordSet and SetPasswordScreen.
    if (!authProvider.hasPasswordSet) {
      return const SetPasswordScreen();
    }

    // Show main app
    return const HomeScreen();
  }
}