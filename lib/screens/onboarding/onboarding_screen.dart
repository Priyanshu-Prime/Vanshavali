import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/common_widgets.dart';
import '../../services/local_storage_service.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingPage> _pages = const [
    _OnboardingPage(
      icon: Icons.account_tree,
      titleKey: 'onboardingTitle1',
      descriptionKey: 'onboardingDesc1',
      color: Color(0xFF1B5E20),
    ),
    _OnboardingPage(
      icon: Icons.family_restroom,
      titleKey: 'onboardingTitle2',
      descriptionKey: 'onboardingDesc2',
      color: Color(0xFF1976D2),
    ),
    _OnboardingPage(
      icon: Icons.share,
      titleKey: 'onboardingTitle3',
      descriptionKey: 'onboardingDesc3',
      color: Color(0xFFFF6F00),
    ),
    _OnboardingPage(
      icon: Icons.privacy_tip_outlined,
      titleKey: 'onboardingTitle4',
      descriptionKey: 'onboardingDesc4',
      color: Color(0xFF6A1B9A),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    await LocalStorageService.setOnboardingCompleted(true);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settingsProvider = context.watch<SettingsProvider>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Language toggle (top-left) + Skip (top-right) — the language
            // switch needs to be visible on the very first screen a
            // low-literacy user sees, before they've read enough English or
            // Gujarati to find it buried in Settings.
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _LanguageToggle(
                    currentCode: settingsProvider.locale.languageCode,
                    englishLabel: l10n.english,
                    gujaratiLabel: l10n.gujarati,
                    onChanged: (code) =>
                        context.read<SettingsProvider>().setLocale(code),
                  ),
                  TextButton(
                    onPressed: _completeOnboarding,
                    child: Text(l10n.skip),
                  ),
                ],
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() => _currentPage = page);
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return _buildPage(context, page, l10n);
                },
              ),
            ),

            // Indicators
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),

            // Button
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  child: Text(
                    _currentPage < _pages.length - 1
                        ? l10n.continueText
                        : l10n.getStarted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(BuildContext context, _OnboardingPage page, dynamic l10n) {
    String title;
    String description;

    switch (page.titleKey) {
      case 'onboardingTitle1':
        title = l10n.onboardingTitle1;
        description = l10n.onboardingDesc1;
        break;
      case 'onboardingTitle2':
        title = l10n.onboardingTitle2;
        description = l10n.onboardingDesc2;
        break;
      case 'onboardingTitle3':
        title = l10n.onboardingTitle3;
        description = l10n.onboardingDesc3;
        break;
      case 'onboardingTitle4':
        title = l10n.onboardingTitle4;
        description = l10n.onboardingDesc4;
        break;
      default:
        title = '';
        description = '';
    }

    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: page.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(page.icon, size: 80, color: page.color),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String titleKey;
  final String descriptionKey;
  final Color color;

  const _OnboardingPage({
    required this.icon,
    required this.titleKey,
    required this.descriptionKey,
    required this.color,
  });
}

/// Two-segment English/Gujarati switch. Labels are shown in their own
/// native script regardless of the currently active locale (see
/// l10n.english/l10n.gujarati, which are deliberately identical in both
/// .arb files) — a user who can't read the active language yet still needs
/// to recognize their own language's name to switch to it.
class _LanguageToggle extends StatelessWidget {
  final String currentCode;
  final String englishLabel;
  final String gujaratiLabel;
  final ValueChanged<String> onChanged;

  const _LanguageToggle({
    required this.currentCode,
    required this.englishLabel,
    required this.gujaratiLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(context, 'en', englishLabel),
          _segment(context, 'gu', gujaratiLabel),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, String code, String label) {
    final theme = Theme.of(context);
    final selected = currentCode == code;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => onChanged(code),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: selected
                ? theme.colorScheme.onPrimary
                : theme.textTheme.bodyMedium?.color,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
