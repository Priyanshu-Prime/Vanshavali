import 'dart:async';
import 'package:app_links/app_links.dart';

import '../utils/invite_code_parser.dart';

class DeepLinkService {
  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription<Uri>? _linkSubscription;

  /// Base URL of the hosted WhatsApp-invite landing page (GitHub Pages).
  /// See docs/whatsapp_invite_flow.md — "The invite URL". Trailing slash is
  /// intentional so `$_landingBaseUrl?c=...` matches the contract exactly.
  static const String _landingBaseUrl =
      'https://priyanshu-prime.github.io/Vanshavali/';

  /// Host of [_landingBaseUrl], used to recognise an incoming Pages link.
  static const String _landingHost = 'priyanshu-prime.github.io';

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

  /// Extracts a 6-character invite code from an incoming deep-link [uri],
  /// handling BOTH supported forms per docs/whatsapp_invite_flow.md:
  ///
  ///   * custom scheme  `vanshavali://invite?code=<CODE>` (also `?c=<CODE>`)
  ///   * hosted https page
  ///     `https://priyanshu-prime.github.io/Vanshavali/?c=<CODE>` (defensive —
  ///     in case an Android App Link is ever configured to route the Pages URL
  ///     straight into the app).
  ///
  /// The candidate is validated/normalised through [parseInviteCode]
  /// (trim + uppercase, must be exactly 6 A–Z/0–9 chars). Returns the
  /// normalised code, or `null` for any other URI or a malformed code.
  static String? parseInviteCodeFromUri(Uri uri) {
    final isCustomInvite = uri.scheme == 'vanshavali' && uri.host == 'invite';
    final isPagesLink =
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host == _landingHost;
    if (!isCustomInvite && !isPagesLink) return null;

    final raw = uri.queryParameters['code'] ?? uri.queryParameters['c'];
    return parseInviteCode(raw);
  }

  /// Parse invite link
  /// Format: vanshavali://invite/{memberId}
  ///
  /// NOTE: This is the LEGACY memberId path form. The invite CODE carried as a
  /// query param (see [parseInviteCodeFromUri]) is the supported mechanism now.
  /// This parser is kept only as a harmless defensive fallback in case a
  /// `vanshavali://invite/<memberId>` URL is ever manually typed/tested while
  /// the app is already running. New invite links never use this path form.
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

  /// Builds the hosted WhatsApp-invite URL for [memberName]/[code] per
  /// docs/whatsapp_invite_flow.md — "The invite URL". Shared on WhatsApp; the
  /// landing page offers the APK download and an "Open in app" button that
  /// fires `vanshavali://invite?code=<CODE>`.
  static String buildInviteUrl(String memberName, String code) {
    return '$_landingBaseUrl?c=$code&n=${Uri.encodeComponent(memberName)}';
  }

  /// Generate share text for an invite.
  ///
  /// [code] is the 6-character invite code from
  /// SupabaseService.generateInviteCode. The text now carries the real hosted
  /// invite link (see [buildInviteUrl]) so a tap opens the landing page, and
  /// still shows the bare code as an always-works manual-entry fallback.
  static String generateInviteText(String memberName, String code, String locale) {
    final link = buildInviteUrl(memberName, code);
    if (locale == 'gu') {
      return 'હું તમને વંશાવલી એપમાં જોડાવા અને આપણા કુટુંબવૃક્ષમાં તમારી પ્રોફાઇલ ($memberName) '
             'મેળવવા માટે આમંત્રણ આપી રહ્યો છું. આ લિંક ખોલો: $link\n'
             'અથવા સાઇન અપ કરતી વખતે આ આમંત્રણ કોડ જાતે દાખલ કરો: $code';
    }

    return 'I\'m inviting you to join Vanshavali and claim your profile ($memberName) in our '
           'family tree. Open this link: $link\n'
           'Or enter this invite code manually when you sign up: $code';
  }
}
