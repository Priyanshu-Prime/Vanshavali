import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

/// Zero-external-dependency crash/error reporting — writes to the
/// `error_logs` table (migration 008) instead of a third-party service like
/// Sentry, to stay within this project's strict zero-cost constraint.
///
/// Known limitation: exception messages are logged as-is. This codebase's
/// own thrown exceptions are structural ("Failed to link new member"), not
/// data-carrying, but a caught PostgrestException could in principle echo
/// back a value from the request. Acceptable for this app's scale; revisit
/// if that ever proves to be a real problem in practice.
class ErrorReportingService {
  /// Hooks Flutter's two top-level error channels. Call once, early in
  /// main() — before runApp(), so failures during startup are covered too.
  static void initialize() {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      // Preserve default behavior (red error screen in debug, console log)
      // — this is additive logging, not a replacement.
      originalOnError?.call(details);
      _report(
        message: details.exceptionAsString(),
        stackTrace: details.stack?.toString(),
        context: 'FlutterError',
      );
    };

    // Catches errors outside the widget build/layout/paint pipeline (e.g. a
    // throw inside an async callback not awaited by any widget) — the
    // modern replacement for wrapping runApp in runZonedGuarded.
    PlatformDispatcher.instance.onError = (error, stack) {
      _report(
        message: error.toString(),
        stackTrace: stack.toString(),
        context: 'PlatformDispatcher',
      );
      return true;
    };
  }

  /// Manually report an exception a provider already caught and handled
  /// for the user (shown a friendly error message, etc.) but still wants
  /// recorded for later investigation — the two hooks above only see
  /// exceptions that go uncaught.
  static void reportCaught(
    Object error,
    StackTrace? stackTrace, {
    String context = 'caught',
  }) {
    _report(
      // Prefix the runtime type so error_logs always shows WHAT kind of failure
      // it was (e.g. AuthRetryableFetchException vs AuthApiException vs
      // PostgrestException) even when the message alone is ambiguous — this is
      // what lets an auth issue be diagnosed from the dashboard without
      // reproducing the whole flow.
      message: '${error.runtimeType}: $error',
      stackTrace: stackTrace?.toString(),
      context: context,
    );
  }

  static Future<void> _report({
    required String message,
    String? stackTrace,
    required String context,
  }) async {
    try {
      await SupabaseService.client.from('error_logs').insert({
        'auth_user_id': SupabaseService.currentUser?.id,
        'error_message': message,
        'stack_trace': stackTrace,
        'context': context,
        'platform': defaultTargetPlatform.name,
      });
    } catch (e) {
      // Never let error reporting itself throw uncaught — that would risk
      // a reporting loop (this failure re-triggering PlatformDispatcher's
      // handler) and defeats the entire purpose of this being a safety net.
      debugPrint('ErrorReportingService failed to report: $e');
    }
  }
}
