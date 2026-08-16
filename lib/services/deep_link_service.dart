import 'dart:async';
import 'package:app_links/app_links.dart';

class DeepLinkService {
  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription<Uri>? _linkSubscription;

  /// Initialize deep link handling
  static Future<Uri?> initialize() async {
    // Get initial link if app was opened via deep link
    final initialLink = await _appLinks.getInitialLink();
    return initialLink;
  }

  /// Listen for incoming deep links
  static void listen(void Function(Uri uri) onLink) {
    _linkSubscription = _appLinks.uriLinkStream.listen(onLink);
  }

  /// Stop listening
  static void dispose() {
    _linkSubscription?.cancel();
  }

  /// Parse invite link
  /// Format: vanshavali://invite/{memberId}
  ///
  /// NOTE: The app no longer generates or shares this link (see
  /// generateInviteText below — invite CODE is the alpha's only supported
  /// claim mechanism). AndroidManifest.xml has no intent-filter for
  /// scheme=vanshavali host=invite either, so this URL never actually opens
  /// the app from outside it. This parser is kept only as a harmless
  /// defensive fallback in case a vanshavali://invite/ URL is ever manually
  /// typed/tested while the app is already running. Do not resurrect
  /// generation of this link without also wiring up the manifest
  /// intent-filter (separate, future work).
  static String? parseInviteLink(Uri uri) {
    if (uri.scheme == 'vanshavali' && uri.host == 'invite') {
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        return pathSegments.first;
      }
    }
    return null;
  }

  /// Parse auth callback
  /// Format: vanshavali://auth/callback
  static bool isAuthCallback(Uri uri) {
    return uri.scheme == 'vanshavali' &&
           uri.host == 'auth' &&
           uri.pathSegments.contains('callback');
  }

  /// Generate share text for an invite.
  ///
  /// [code] is the 6-character invite code from
  /// SupabaseService.generateInviteCode — the only mechanism the alpha
  /// supports for claiming a placeholder profile (typed on the signup
  /// screen, resolved via the claim_profile_by_code RPC). This text
  /// intentionally contains no link.
  //
  // TODO: Once the app has a published Play Store listing, replace the
  // "[App download link — coming soon]" placeholder below (both locales)
  // with the real store URL.
  static String generateInviteText(String memberName, String code, String locale) {
    if (locale == 'gu') {
      return 'હું તમને વંશાવલી એપમાં જોડાવા અને આપણા કુટુંબવૃક્ષમાં તમારી પ્રોફાઇલ ($memberName) '
             'મેળવવા માટે આમંત્રણ આપી રહ્યો છું. એપ ડાઉનલોડ કરો [એપ ડાઉનલોડ લિંક ટૂંક સમયમાં ઉપલબ્ધ થશે] '
             'અને સાઇન અપ કરતી વખતે આ આમંત્રણ કોડ દાખલ કરો: $code';
    }

    return 'I\'m inviting you to join Vanshavali and claim your profile ($memberName) in our '
           'family tree. Download the app [App download link — coming soon] and enter this '
           'invite code when you sign up: $code';
  }
}
