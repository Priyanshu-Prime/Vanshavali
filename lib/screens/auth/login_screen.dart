import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/common_widgets.dart';
import 'signup_screen.dart';
import 'phone_auth_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPasswordLogin = false;
  bool _isLoading = false;
  bool _magicLinkSent = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _sendMagicLink() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signInWithMagicLink(
      _emailController.text.trim(),
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        setState(() => _magicLinkSent = true);
        showAppSnackBar(context, context.l10n.magicLinkSent);
      } else if (authProvider.error != null) {
        showAppSnackBar(
          context,
          friendlyErrorMessage(context, authProvider.error!),
          isError: true,
        );
      }
    }
  }

  Future<void> _signInWithPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signInWithEmail(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (!success && authProvider.error != null) {
        showAppSnackBar(
          context,
          friendlyErrorMessage(context, authProvider.error!),
          isError: true,
        );
      }
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final resetEmailController = TextEditingController(
      text: _emailController.text,
    );
    final l10n = context.l10n;

    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.resetPasswordTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.resetPasswordDesc),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: resetEmailController,
              decoration: InputDecoration(
                labelText: l10n.email,
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(ctx, resetEmailController.text.trim()),
            child: Text(l10n.send),
          ),
        ],
      ),
    );

    if (email != null && email.isNotEmpty && mounted) {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.resetPassword(email);
      if (mounted) {
        if (success) {
          showAppSnackBar(context, l10n.resetLinkSent);
        } else if (authProvider.error != null) {
          showAppSnackBar(
            context,
            friendlyErrorMessage(context, authProvider.error!),
            isError: true,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xxl),
                // Logo/Title
                Icon(
                  Icons.account_tree_outlined,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.welcomeMessage,
                  style: Theme.of(context).textTheme.displaySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.welcomeSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xxl),

                if (_magicLinkSent) ...[
                  // Magic link sent state
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.mark_email_read_outlined,
                            size: 64,
                            color: Colors.green,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            l10n.magicLinkSent,
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            _emailController.text,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          TextButton(
                            onPressed: () {
                              setState(() => _magicLinkSent = false);
                            },
                            child: Text(l10n.retry),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  // Email field
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: l10n.email,
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: _showPasswordLogin
                        ? TextInputAction.next
                        : TextInputAction.done,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l10n.required;
                      }
                      if (!value.contains('@')) {
                        return l10n.invalidEmail;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),

                  if (_showPasswordLogin) ...[
                    // Password field
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
                      textInputAction: TextInputAction.done,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return l10n.required;
                        }
                        if (value.length < 6) {
                          return l10n.passwordTooShort;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _showForgotPasswordDialog(),
                        child: Text(l10n.forgotPassword),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _signInWithPassword,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.login),
                    ),
                  ] else ...[
                    // Magic link button
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _sendMagicLink,
                      icon: const Icon(Icons.auto_awesome),
                      label: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.sendMagicLink),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.lg),

                  // Divider
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: Text(
                          l10n.orContinueWith,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Toggle password login
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _showPasswordLogin = !_showPasswordLogin);
                    },
                    icon: Icon(
                      _showPasswordLogin ? Icons.auto_awesome : Icons.password,
                    ),
                    label: Text(
                      _showPasswordLogin
                          ? l10n.sendMagicLink
                          : l10n.emailPassword,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Phone (SMS OTP) — no email needed, for users without one.
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PhoneAuthScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.smartphone),
                    label: Text(l10n.continueWithPhone),
                  ),
                ],

                const SizedBox(height: AppSpacing.xl),

                // Sign up link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(l10n.dontHaveAccount),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SignupScreen(),
                          ),
                        );
                      },
                      child: Text(l10n.signUp),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
