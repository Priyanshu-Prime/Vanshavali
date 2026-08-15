import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/common_widgets.dart';

/// Mandatory, non-dismissible screen shown (via AppNavigator) to any
/// authenticated user whose account has never had a password set — i.e.
/// magic-link-only accounts. Deliberately has no back button, no skip
/// option, and blocks the Android back gesture: the user must set a
/// password to proceed into the app. See AuthProvider.hasPasswordSet.
///
/// Setting a password is a live Supabase Auth call with no offline queueing
/// (unlike data edits, which sync later via LocalStorageService). A user who
/// reopens the app offline with a persisted session but no password yet set
/// would otherwise be stuck here with no way out until they get connectivity
/// — so a sign-out escape hatch is offered instead of a way to bypass into
/// the app itself.
class SetPasswordScreen extends StatefulWidget {
  const SetPasswordScreen({super.key});

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.setPassword(_passwordController.text);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      showAppSnackBar(context, context.l10n.passwordSetSuccess);
      // No navigation needed — AppNavigator watches hasPasswordSet and
      // rebuilds to HomeScreen automatically once it flips to true.
    } else if (authProvider.error != null) {
      showAppSnackBar(
        context,
        friendlyErrorMessage(context, authProvider.error!),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return PopScope(
      // Non-dismissible: no back navigation until a password is set.
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.setPasswordTitle),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.lg),
                  Icon(
                    Icons.lock_outline,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.setPasswordTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.setPasswordDescription,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: l10n.password,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.isEmpty) return l10n.required;
                      if (value.length < 6) return l10n.passwordTooShort;
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: l10n.confirmPassword,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(
                          () => _obscureConfirmPassword =
                              !_obscureConfirmPassword,
                        ),
                      ),
                    ),
                    obscureText: _obscureConfirmPassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    validator: (value) {
                      if (value == null || value.isEmpty) return l10n.required;
                      if (value != _passwordController.text) {
                        return l10n.passwordsDoNotMatch;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.setPasswordButton),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            final confirmed = await showConfirmDialog(
                              context: context,
                              title: l10n.logout,
                              message: l10n.confirmLogout,
                              isDestructive: true,
                            );
                            if (confirmed && context.mounted) {
                              await context.read<AuthProvider>().signOut();
                            }
                          },
                    child: Text(l10n.logout),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
