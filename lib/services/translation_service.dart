import 'dart:developer' as dev;
import 'package:translator/translator.dart';

class TranslationService {
  static final GoogleTranslator _translator = GoogleTranslator();

  /// Translate text from English to Gujarati
  static Future<String?> translateToGujarati(String text) async {
    if (text.trim().isEmpty) return null;

    try {
      final translation = await _translator.translate(
        text,
        from: 'en',
        to: 'gu',
      );
      return translation.text;
    } catch (e) {
      dev.log('Translation error: $e', name: 'TranslationService');
      return null;
    }
  }
}
