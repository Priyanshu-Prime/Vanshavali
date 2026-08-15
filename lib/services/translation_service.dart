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

  /// Translate text from Gujarati to English
  static Future<String?> translateToEnglish(String text) async {
    if (text.trim().isEmpty) return null;
    
    try {
      final translation = await _translator.translate(
        text,
        from: 'gu',
        to: 'en',
      );
      return translation.text;
    } catch (e) {
      dev.log('Translation error: $e', name: 'TranslationService');
      return null;
    }
  }

  /// Transliterate English to Gujarati script (approximate)
  /// This is a basic mapping - for production, use a proper transliteration API
  static String transliterateToGujarati(String text) {
    // Basic vowel and consonant mappings
    final Map<String, String> mappings = {
      'a': 'અ', 'aa': 'આ', 'i': 'ઇ', 'ii': 'ઈ', 'u': 'ઉ', 'uu': 'ઊ',
      'e': 'એ', 'ai': 'ઐ', 'o': 'ઓ', 'au': 'ઔ',
      'k': 'ક', 'kh': 'ખ', 'g': 'ગ', 'gh': 'ઘ', 'ng': 'ઙ',
      'ch': 'ચ', 'chh': 'છ', 'j': 'જ', 'jh': 'ઝ', 'ny': 'ઞ',
      't': 'ટ', 'th': 'ઠ', 'd': 'ડ', 'dh': 'ઢ', 'n': 'ણ',
      'ta': 'ત', 'tha': 'થ', 'da': 'દ', 'dha': 'ધ', 'na': 'ન',
      'p': 'પ', 'ph': 'ફ', 'b': 'બ', 'bh': 'ભ', 'm': 'મ',
      'y': 'ય', 'r': 'ર', 'l': 'લ', 'v': 'વ', 'w': 'વ',
      'sh': 'શ', 's': 'સ', 'h': 'હ',
    };

    String result = text.toLowerCase();
    
    // Sort by length descending to match longer sequences first
    final sortedKeys = mappings.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (var key in sortedKeys) {
      result = result.replaceAll(key, mappings[key]!);
    }

    return result;
  }
}
