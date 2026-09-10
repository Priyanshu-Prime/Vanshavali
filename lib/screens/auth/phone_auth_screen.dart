import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/common_widgets.dart';

/// Phone + SMS-OTP sign-in / sign-up (via Supabase's Twilio provider).
///
/// Two steps in one screen: enter phone → enter the 6-digit code. On a
/// successful verify, AuthProvider flips to authenticated and the root
/// AppNavigator swaps to Home, so we just pop back to the root.
class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  bool _codeSent = false;
  bool _isLoading = false;
  String? _sentPhone; // the E.164 number we actually sent the code to

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  /// Normalizes user input to E.164. A bare 10-digit Indian number gets +91;
  /// anything already starting with + is kept as-is (spaces/dashes stripped).
  String _toE164(String raw) {
    var s = raw.trim().replaceAll(RegExp(r'[\s\-()]'), '');
    if (s.startsWith('+')) return s;
    if (s.startsWith('0')) s = s.substring(1);
    if (s.length == 10) return '+91$s';
    return '+$s';
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final phone = _toE164(_phoneController.text);
    final authProvider = context.read<AuthProvider>();
    final ok = await authProvider.sendPhoneOtp(phone);

    if (!mounted) return;
    setState(() => _isLoading = false);
    if (ok) {
      setState(() {
        _codeSent = true;
        _sentPhone = phone;
      });
      showAppSnackBar(context, context.l10n.otpSentSms);
    } else if (authProvider.error != null) {
      showAppSnackBar(
        context,
        friendlyErrorMessage(context, authProvider.error!),
        isError: true,
      );
    }
  }

  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final ok = await authProvider.verifyPhoneOtp(
      _sentPhone!,
      _codeController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);
    if (ok) {
      // Authenticated — the root navigator now shows Home; drop this screen
      // (and the login screen it was pushed from).
      Navigator.of(context).popUntil((r) => r.isFirst);
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.continueWithPhone)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.lg),
                Icon(Icons.smartphone,
                    size: 72, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: AppSpacing.lg),

                if (!_codeSent) ...[
                  Text(l10n.enterPhoneNumber,
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: l10n.phoneNumber,
                      prefixIcon: const Icon(Icons.phone_outlined),
                      hintText: '+91 98765 43210',
                    ),
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    validator: (v) {
                      final digits =
                          (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                      if (digits.length < 10) return l10n.invalidPhone;
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _sendCode,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(l10n.sendCode),
                  ),
                ] else ...[
                  Text(l10n.otpSentSms,
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center),
                  if (_sentPhone != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(_sentPhone!,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      labelText: l10n.enterCode,
                      prefixIcon: const Icon(Icons.lock_clock_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    maxLength: 6,
                    style: const TextStyle(fontSize: 22, letterSpacing: 8),
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    autofillHints: const [AutofillHints.oneTimeCode],
                    validator: (v) {
                      if ((v ?? '').trim().length != 6) return l10n.invalidCode;
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _verifyCode,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(l10n.verifyCode),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => setState(() {
                                  _codeSent = false;
                                  _codeController.clear();
                                }),
                        child: Text(l10n.changeNumber),
                      ),
                      TextButton(
                        onPressed: _isLoading ? null : _sendCode,
                        child: Text(l10n.resendCode),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
