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

  /// Generate invite link
  static String generateInviteLink(String memberId) {
    return 'vanshavali://invite/$memberId';
  }

  /// Generate share text for invite
  static String generateInviteText(String memberName, String memberId, String locale) {
    final link = generateInviteLink(memberId);
    
    if (locale == 'gu') {
      return 'હું તમને વંશાવલી એપ પર આમંત્રિત કરી રહ્યો છું. '
             'કૃપા કરીને એપ ઇન્સ્ટોલ કરો અને આ લિંક પર ક્લિક કરો તમારી પ્રોફાઇલ મેળવવા માટે:\n$link';
    }
    
    return 'I\'m inviting you to join Vanshavali app. '
           'Please install the app and click this link to claim your profile:\n$link';
  }
}
