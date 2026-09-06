import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/common_widgets.dart';
import '../scan/scan_invite_code_screen.dart';

class SignupScreen extends StatefulWidget {
  /// Optional invite code to prefill the invite-code field with — supplied by
  /// the WhatsApp deep-link flow (see main.dart `_handleDeepLink`) so an
  /// invitee never has to type it. Manual entry and the QR scanner still work.
  final String? prefilledInviteCode;

  const SignupScreen({super.key, this.prefilledInviteCode});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _invitePreviewName;

  @override
  void initState() {
    super.initState();
    // Prefill the invite code delivered by the deep-link flow, if any, and run
    // the same preview lookup that manual typing / scanning triggers.
    final code = widget.prefilledInviteCode;
    if (code != null && code.isNotEmpty) {
      debugPrint('signup: prefilled invite code from deep link: $code');
      _inviteCodeController.text = code;
      _lookupInviteCode(code);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  /// Opens the QR scanner; on a successful scan fills the invite-code field
  /// and runs the same preview lookup as manual typing. Manual entry is never
  /// disabled — this is an optional shortcut.
  Future<void> _scanInviteCode() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScanInviteCodeScreen()),
    );
    if (code == null || !mounted) return;
    _inviteCodeController.text = code;
    _lookupInviteCode(code);
  }

  Future<void> _lookupInviteCode(String code) async {
    if (code.length != 6) {
      setState(() => _invitePreviewName = null);
      return;
    }
    try {
      final member = await SupabaseService.getMemberByInviteCode(code);
      if (mounted) {
        setState(() {
          _invitePreviewName = member?.fullNameEn;
        });
      }
    } catch (_) {}
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signUpWithEmail(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (mounted && success) {
      // If invite code was entered, claim the profile
      final code = _inviteCodeController.text.trim().toUpperCase();
      if (code.length == 6) {
        debugPrint('deeplink: claim attempt starting for code');
        final claimed = await authProvider.claimProfileByCode(code);
        debugPrint('deeplink: claim attempt result: '
            '${claimed ? 'success' : authProvider.hasPendingMergeConflict ? 'merge-conflict (flagged for review)' : 'failed (invalid code)'}');
        if (mounted) {
          if (claimed) {
            showAppSnackBar(context, context.l10n.profileClaimed);
          } else if (authProvider.hasPendingMergeConflict) {
            // Not a real failure — the invitee already has their own
            // profile, and this specific placeholder was flagged for
            // manual review instead. Reassure, don't alarm.
            showAppSnackBar(
              context,
              context.l10n.duplicateProfileFlaggedForReview,
            );
            authProvider.acknowledgeMergeConflict();
          } else {
            showAppSnackBar(
              context,
              context.l10n.invalidInviteCode,
              isError: true,
            );
          }
        }
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        Navigator.pop(context);
      } else if (authProvider.error != null) {
        showAppSnackBar(
          context,
          friendlyErrorMessage(context, authProvider.error!),
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.createAccount)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.lg),
                // Header
                Text(
                  l10n.createAccount,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.welcomeSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Email field
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: l10n.email,
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
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
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
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
                const SizedBox(height: AppSpacing.md),

                // Confirm password field
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
                      onPressed: () {
                        setState(
                          () => _obscureConfirmPassword =
                              !_obscureConfirmPassword,
                        );
                      },
                    ),
                  ),
                  obscureText: _obscureConfirmPassword,
                  textInputAction: TextInputAction.done,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.required;
                    }
                    if (value != _passwordController.text) {
                      return l10n.passwordsDoNotMatch;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.xl),

                // ── Invite Code (optional) ──
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.card_giftcard,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.enterInviteCode,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _inviteCodeController,
                          decoration: InputDecoration(
                            hintText: l10n.enterInviteCodeHint,
                            prefixIcon: const Icon(Icons.key),
                          ),
                          textCapitalization: TextCapitalization.characters,
                          textInputAction: TextInputAction.done,
                          maxLength: 6,
                          onChanged: _lookupInviteCode,
                        ),
                        // Optional QR shortcut — manual typing above always works.
                        OutlinedButton.icon(
                          onPressed: _scanInviteCode,
                          icon: const Icon(Icons.qr_code_scanner),
                          label: Text(l10n.scanInviteCode),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                          ),
                        ),
                        if (_invitePreviewName != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green.shade700,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _invitePreviewName!,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Sign up button
                ElevatedButton(
                  onPressed: _isLoading ? null : _signUp,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.signUp),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Login link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(l10n.alreadyHaveAccount),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l10n.login),
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
