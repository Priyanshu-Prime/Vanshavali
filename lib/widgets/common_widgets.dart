import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/translation_service.dart';
import '../theme/app_spacing.dart';

/// Extension to easily access localizations
extension LocalizationsExt on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

/// Maps a caught exception to a plain-language, localized message safe to
/// show to non-technical users.
///
/// For this audience, a raw Dart/Postgrest exception string (stack traces,
/// error codes, "PostgrestException: ...") is meaningless and alarming.
/// Never pass `error.toString()` straight into a snackbar or dialog — use
/// this instead. [error] can be the original caught exception, or a string
/// already produced by `.toString()` (e.g. a provider's `error` field) —
/// both are matched the same way.
String friendlyErrorMessage(BuildContext context, Object error) {
  final l10n = context.l10n;
  final text = error.toString().toLowerCase();

  final isOffline =
      text.contains('socketexception') ||
      text.contains('failed host lookup') ||
      text.contains('network is unreachable') ||
      text.contains('no address associated') ||
      text.contains('connection refused') ||
      text.contains('no internet');
  if (isOffline) return l10n.errorNoInternet;

  // Checked before the generic isServiceFailure bucket below, which would
  // otherwise swallow this into an unhelpful "something went wrong" toast —
  // see SupabaseService.signUpWithEmail for where this is thrown.
  if (text.contains('vanshavali_email_already_registered')) {
    return l10n.errorEmailAlreadyRegistered;
  }

  if (text.contains('vanshavali_email_confirmation_required')) {
    return l10n.errorEmailConfirmationRequired;
  }

  // Supabase's own message when confirmations are required and the user
  // tries to sign in before clicking the link — thrown from signInWithPassword.
  if (text.contains('email not confirmed') || text.contains('email_not_confirmed')) {
    return l10n.errorEmailNotConfirmed;
  }

  // Supabase's own guard in updateUser() when the "new" password matches the
  // account's current one — surfaced most often on SetPasswordScreen when a
  // user re-enters a password they'd already set moments earlier.
  if (text.contains('different from the old password') ||
      text.contains('should be different')) {
    return l10n.errorPasswordSameAsOld;
  }

  final isTimeout =
      text.contains('timeoutexception') ||
      text.contains('timed out') ||
      text.contains('timeout');
  if (isTimeout) return l10n.errorTimeout;

  // A relation-link / edit write that RLS filtered out (no permission to edit
  // this node) — thrown as a sentinel by SupabaseService._updateMemberOrThrow
  // so it doesn't get swallowed by the generic service-failure bucket below.
  if (text.contains('vanshavali_edit_not_permitted')) {
    return l10n.errorEditNotPermitted;
  }

  final isServiceFailure =
      text.contains('postgrestexception') ||
      text.contains('authexception') ||
      text.contains('authapiexception') ||
      text.contains('authretryablefetchexception') ||
      text.contains('storageexception');
  if (isServiceFailure) return l10n.errorServiceFailure;

  return l10n.errorGeneric;
}

/// Common UI widgets
class AppWidgets {
  /// Loading indicator
  static Widget loading({String? message}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[const SizedBox(height: 16), Text(message)],
        ],
      ),
    );
  }

  /// Error widget
  static Widget error({
    required String message,
    VoidCallback? onRetry,
    required BuildContext context,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(context.l10n.retry),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Empty state widget
  static Widget empty({
    required String message,
    String? subtitle,
    IconData icon = Icons.inbox_outlined,
    Widget? action,
  }) {
    return Builder(
      builder: (context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 80,
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
              if (action != null) ...[const SizedBox(height: 24), action],
            ],
          ),
        ),
      ),
    );
  }

  /// Offline banner
  static Widget offlineBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.orange.shade800,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            context.l10n.offlineMode,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// A card with a title and a padded, top-aligned column of content —
/// the common "Card > Padding > Column(title, ...content)" section pattern
/// repeated across settings, profile, and add-family-member screens.
class SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final double titleSpacing;
  final Color? color;

  const SectionCard({
    super.key,
    required this.title,
    required this.children,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.titleSpacing = AppSpacing.md,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: titleSpacing),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Custom text field with translation support
class BilingualTextField extends StatefulWidget {
  final TextEditingController englishController;
  final TextEditingController? gujaratiController;
  final String label;
  final String? gujaratiLabel;
  final String? hint;
  final bool showTranslateButton;
  final bool required;
  final int maxLines;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const BilingualTextField({
    super.key,
    required this.englishController,
    this.gujaratiController,
    required this.label,
    this.gujaratiLabel,
    this.hint,
    this.showTranslateButton = true,
    this.required = false,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  State<BilingualTextField> createState() => _BilingualTextFieldState();
}

class _BilingualTextFieldState extends State<BilingualTextField> {
  bool _isTranslating = false;

  Future<void> _translate() async {
    if (widget.gujaratiController == null) return;
    if (widget.englishController.text.isEmpty) return;

    setState(() => _isTranslating = true);

    try {
      final translated = await TranslationService.translateToGujarati(
        widget.englishController.text,
      );

      if (mounted && translated != null && translated.isNotEmpty) {
        widget.gujaratiController!.text = translated;
      }
    } catch (e) {
      debugPrint('Translation error: $e');
    } finally {
      if (mounted) {
        setState(() => _isTranslating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.englishController,
          decoration: InputDecoration(
            labelText: widget.required ? '${widget.label} *' : widget.label,
            hintText: widget.hint,
          ),
          maxLines: widget.maxLines,
          keyboardType: widget.keyboardType,
          validator:
              widget.validator ??
              (widget.required
                  ? (value) =>
                        value?.isEmpty == true ? context.l10n.required : null
                  : null),
        ),
        if (widget.gujaratiController != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: widget.gujaratiController,
                  decoration: InputDecoration(
                    labelText:
                        widget.gujaratiLabel ?? '${widget.label} (ગુજરાતી)',
                  ),
                  maxLines: widget.maxLines,
                  keyboardType: widget.keyboardType,
                ),
              ),
              if (widget.showTranslateButton) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isTranslating ? null : _translate,
                  icon: _isTranslating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.translate),
                  tooltip: context.l10n.translateToGujarati,
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// Confirmation dialog
Future<bool> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String? confirmText,
  String? cancelText,
  bool isDestructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelText ?? context.l10n.cancel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: isDestructive
              ? ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                )
              : null,
          child: Text(confirmText ?? context.l10n.continueText),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Show snackbar helper
void showAppSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
  Duration duration = const Duration(seconds: 3),
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: duration,
      backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
    ),
  );
}
