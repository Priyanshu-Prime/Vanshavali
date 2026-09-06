import 'dart:convert';
import 'dart:developer' as dev;

import 'package:http/http.dart' as http;

/// Phonetic transliteration of Latin-typed names into Gujarati script.
///
/// This is deliberately NOT translation. A name like "Rose" must become its
/// Gujarati *spelling* (રોઝ), never its meaning (ગુલાબ) — the old code used the
/// Google Translate endpoint, which translated real-word names into unrelated
/// Gujarati words. Here we use Google Input Tools (the same engine behind Indic
/// typing in Gmail/Docs), which returns several ranked phonetic candidates and
/// handles matras/conjuncts correctly.
class TransliterationService {
  static final http.Client _client = http.Client();

  /// Returns ranked Gujarati spelling candidates for a Latin-script [input]
  /// (e.g. "ramesh" -> ["રમેશ", "રામેશ", "રમીશ", ...]). Best guess first.
  ///
  /// Returns an empty list on empty input, network failure, or offline — the
  /// caller keeps whatever the user already typed rather than clobbering it.
  /// Multi-word input (e.g. a full name) is transliterated word-by-word and the
  /// top candidate of each is joined, while single words return the full
  /// candidate list for the user to choose from.
  static Future<List<String>> candidates(String input, {int num = 5}) async {
    final text = input.trim();
    if (text.isEmpty) return const [];

    final words = text.split(RegExp(r'\s+'));
    if (words.length > 1) {
      final parts = <String>[];
      for (final w in words) {
        final c = await _candidatesForWord(w, num: 1);
        parts.add(c.isNotEmpty ? c.first : w);
      }
      return [parts.join(' ')];
    }
    return _candidatesForWord(text, num: num);
  }

  /// Convenience: the single best Gujarati spelling for [input], or null if
  /// none could be produced (used for the auto-fill as the user types).
  static Future<String?> best(String input) async {
    final c = await candidates(input, num: 1);
    return c.isEmpty ? null : c.first;
  }

  static Future<List<String>> _candidatesForWord(
    String word, {
    required int num,
  }) async {
    // itc=gu-t-i0-und selects English->Gujarati transliteration; num caps the
    // number of returned candidates.
    final uri = Uri.parse(
      'https://inputtools.google.com/request'
      '?text=${Uri.encodeQueryComponent(word.toLowerCase())}'
      '&itc=gu-t-i0-und&num=$num&cp=0&cs=1&ie=utf-8&oe=utf-8',
    );
    try {
      final res = await _client
          .get(uri)
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return const [];
      return parseInputToolsResponse(res.body);
    } catch (e) {
      dev.log('Transliteration error: $e', name: 'TransliterationService');
      return const [];
    }
  }

  /// Parses a Google Input Tools response body into the candidate list.
  ///
  /// Success shape:
  ///   ["SUCCESS",[["ramesh",["રમેશ","રામેશ",...],[],{...}]]]
  /// Anything else (including "FAILED") yields an empty list. Extracted and made
  /// public so it can be unit-tested without a network call.
  static List<String> parseInputToolsResponse(String body) {
    try {
      final decoded = json.decode(body);
      if (decoded is! List || decoded.isEmpty || decoded[0] != 'SUCCESS') {
        return const [];
      }
      final results = decoded[1];
      if (results is! List || results.isEmpty) return const [];
      final first = results[0];
      if (first is! List || first.length < 2) return const [];
      final cands = first[1];
      if (cands is! List) return const [];
      return cands.whereType<String>().where((s) => s.isNotEmpty).toList();
    } catch (_) {
      return const [];
    }
  }
}
