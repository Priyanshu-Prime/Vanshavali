import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// A place from the Census 2011 Gujarat directory. [code] is the stable MDDS
/// code (district DTC, sub-district SUB_DT, or village PLCN) used as the
/// canonical key so the same place always resolves identically regardless of
/// spelling.
class GjPlace {
  final String name;
  final String code;
  const GjPlace(this.name, this.code);
}

/// Loads and queries the bundled Gujarat district -> taluka -> village
/// directory (assets/data/gujarat_places.json). Village entry in the app is a
/// strict pick from this list — never free text — so village_origin stays
/// uniform across the whole database.
class GujaratPlacesService {
  static const _assetPath = 'assets/data/gujarat_places.json';

  // districtCode -> {name, talukas: talukaCode -> {name, villages: [GjPlace]}}
  static Map<String, dynamic>? _byDistrict;
  static List<GjPlace> _districts = const [];

  static bool get isLoaded => _byDistrict != null;

  /// Loads the asset once (idempotent). Safe to call from app start or lazily
  /// before showing the picker.
  static Future<void> load() async {
    if (_byDistrict != null) return;
    final raw = await rootBundle.loadString(_assetPath);
    loadFromJson(raw);
  }

  /// Testable seam: build the in-memory indexes from a JSON string.
  static void loadFromJson(String raw) {
    final data = json.decode(raw) as Map<String, dynamic>;
    final districts = (data['districts'] as List).cast<Map<String, dynamic>>();
    final byDistrict = <String, dynamic>{};
    final dlist = <GjPlace>[];
    for (final d in districts) {
      dlist.add(GjPlace(d['name'] as String, d['code'] as String));
      byDistrict[d['code'] as String] = d;
    }
    _districts = dlist;
    _byDistrict = byDistrict;
  }

  static List<GjPlace> districts() => _districts;

  static List<GjPlace> talukas(String districtCode) {
    final d = _byDistrict?[districtCode] as Map<String, dynamic>?;
    if (d == null) return const [];
    return (d['talukas'] as List)
        .cast<Map<String, dynamic>>()
        .map((t) => GjPlace(t['name'] as String, t['code'] as String))
        .toList();
  }

  static List<GjPlace> villages(String districtCode, String talukaCode) {
    final d = _byDistrict?[districtCode] as Map<String, dynamic>?;
    if (d == null) return const [];
    final t = (d['talukas'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((t) => t['code'] == talukaCode, orElse: () => const {});
    final vs = t['villages'] as List?;
    if (vs == null) return const [];
    return vs
        .cast<Map<String, dynamic>>()
        .map((v) => GjPlace(v['name'] as String, v['code'] as String))
        .toList();
  }

  /// Case/space-insensitive village name search across the whole state, for
  /// normalizing legacy free-text values and for a type-to-filter picker.
  /// Returns up to [limit] matches, exact/prefix matches first.
  static List<GjPlace> searchVillages(String query, {int limit = 30}) {
    final q = _norm(query);
    if (q.isEmpty || _byDistrict == null) return const [];
    final exact = <GjPlace>[];
    final prefix = <GjPlace>[];
    final contains = <GjPlace>[];
    for (final d in _byDistrict!.values.cast<Map<String, dynamic>>()) {
      for (final t in (d['talukas'] as List).cast<Map<String, dynamic>>()) {
        for (final v in (t['villages'] as List).cast<Map<String, dynamic>>()) {
          final name = v['name'] as String;
          final n = _norm(name);
          if (n == q) {
            exact.add(GjPlace(name, v['code'] as String));
          } else if (n.startsWith(q)) {
            prefix.add(GjPlace(name, v['code'] as String));
          } else if (n.contains(q)) {
            contains.add(GjPlace(name, v['code'] as String));
          }
          if (exact.length >= limit) return exact;
        }
      }
    }
    return [...exact, ...prefix, ...contains].take(limit).toList();
  }

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}
